(**************************************************************************)
(*                                BELENIOS                                *)
(*                                                                        *)
(*  Copyright © 2012-2018 Inria                                           *)
(*                                                                        *)
(*  This program is free software: you can redistribute it and/or modify  *)
(*  it under the terms of the GNU Affero General Public License as        *)
(*  published by the Free Software Foundation, either version 3 of the    *)
(*  License, or (at your option) any later version, with the additional   *)
(*  exemption that compiling, linking, and/or using OpenSSL is allowed.   *)
(*                                                                        *)
(*  This program is distributed in the hope that it will be useful, but   *)
(*  WITHOUT ANY WARRANTY; without even the implied warranty of            *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *)
(*  Affero General Public License for more details.                       *)
(*                                                                        *)
(*  You should have received a copy of the GNU Affero General Public      *)
(*  License along with this program.  If not, see                         *)
(*  <http://www.gnu.org/licenses/>.                                       *)
(**************************************************************************)

open Lwt
open Eliom_service
open Platform
open Serializable_builtin_t
open Web_serializable_j
open Web_common
open Web_state
open Web_services

let ( / ) = Filename.concat

let next_lf str i =
  try Some (String.index_from str i '\n')
  with Not_found -> None

let scope = Eliom_common.default_session_scope

let auth_env = Eliom_reference.eref ~scope None

let default_cont uuid () =
  match%lwt cont_pop () with
  | Some f -> f ()
  | None ->
     match uuid with
     | None ->
        Eliom_registration.(Redirection.send (Redirection Web_services.admin))
     | Some u ->
        Eliom_registration.(Redirection.send (Redirection (preapply Web_services.election_home (u, ()))))

(** Dummy authentication *)

let dummy_handler () name =
  match%lwt Eliom_reference.get auth_env with
  | None -> failwith "dummy handler was invoked without environment"
  | Some (uuid, service, _) ->
     let%lwt () = Eliom_reference.set user (Some {uuid; service; name}) in
     let%lwt () = Eliom_reference.unset auth_env in
     default_cont uuid ()

let () = Eliom_registration.Any.register ~service:dummy_post dummy_handler

(** Password authentication *)

let check_password_with_file db name password =
  let%lwt db = Lwt_preemptive.detach Csv.load db in
  try
    begin
      match
        List.find (function
            | username :: _ :: _ :: _ -> username = name
            | _ -> false
          ) db
      with
      | _ :: salt :: hashed :: _ ->
         return (sha256_hex (salt ^ password) = hashed)
      | _ -> return false
    end
  with Not_found -> return false

let password_handler () (name, password) =
  let%lwt uuid, service, config =
    match%lwt Eliom_reference.get auth_env with
    | None -> failwith "password handler was invoked without environment"
    | Some x -> return x
  in
  let%lwt ok =
    match uuid with
    | None ->
       begin
         match config with
         | db :: _ -> check_password_with_file db name password
         | _ -> failwith "invalid configuration for admin site"
       end
    | Some uuid ->
       let uuid_s = raw_string_of_uuid uuid in
       let db = !spool_dir / uuid_s / "passwords.csv" in
       check_password_with_file db name password
  in
  if ok then
    let%lwt () = Eliom_reference.set user (Some {uuid; service; name}) in
    let%lwt () = Eliom_reference.unset auth_env in
    default_cont uuid ()
  else
    fail_http 401

let () = Eliom_registration.Any.register ~service:password_post password_handler

let get_password_db_fname () =
  let rec find = function
    | [] -> None
    | (_, ("password", db :: allowsignups :: _)) :: _ when bool_of_string allowsignups -> Some db
    | _ :: xs -> find xs
  in find !site_auth_config

let allowsignups () = get_password_db_fname () <> None

let password_db_mutex = Lwt_mutex.create ()

let do_add_account ~db_fname ~username ~password ~email () =
  let%lwt db = Lwt_preemptive.detach Csv.load db_fname in
  let%lwt salt = generate_token ~length:8 () in
  let hashed = sha256_hex (salt ^ password) in
  let rec append accu = function
    | [] -> Some (List.rev ([username; salt; hashed; email] :: accu))
    | ((username' :: _ :: _ :: _) as x) :: xs ->
       if username = username' then None else append (x :: accu) xs
    | _ :: _ -> None
  in
  match append [] db with
  | None -> Lwt.return false
  | Some db ->
     let db = List.map (String.concat ",") db in
     let%lwt () = write_file db_fname db in
     Lwt.return true

let username_rex = "^[A-Z0-9._%+-]+$"

let is_username =
  let rex = Pcre.regexp ~flags:[`CASELESS] username_rex in
  fun x ->
  try ignore (Pcre.pcre_exec ~rex x); true
  with Not_found -> false

let add_account ~username ~password ~email =
  if is_username username then
    match%lwt Web_signup.cracklib_check password with
    | Some e -> return (Some (BadPassword e))
    | None ->
       match get_password_db_fname () with
       | None -> forbidden ()
       | Some db_fname ->
          if%lwt Lwt_mutex.with_lock password_db_mutex
               (do_add_account ~db_fname ~username ~password ~email)
          then return None
          else return (Some UsernameTaken)
  else return (Some BadUsername)

(** CAS authentication *)

let cas_server = Eliom_reference.eref ~scope None

let login_cas = Eliom_service.create
  ~path:(Eliom_service.Path ["auth"; "cas"])
  ~meth:(Eliom_service.Get Eliom_parameter.(opt (string "ticket")))
  ()

let cas_self =
  (* lazy so rewrite_prefix is called after server initialization *)
  lazy (Eliom_uri.make_string_uri
          ~absolute:true
          ~service:(preapply login_cas None)
          () |> rewrite_prefix)

let parse_cas_validation info =
  match next_lf info 0 with
  | Some i ->
     (match String.sub info 0 i with
     | "yes" -> `Yes
        (match next_lf info (i+1) with
        | Some j -> Some (String.sub info (i+1) (j-i-1))
        | None -> None)
     | "no" -> `No
     | _ -> `Error `Parsing)
  | None -> `Error `Parsing

let get_cas_validation server ticket =
  let url =
    let cas_validate = Eliom_service.extern
      ~prefix:server
      ~path:["validate"]
      ~meth:(Eliom_service.Get Eliom_parameter.(string "service" ** string "ticket"))
      ()
    in
    let service = preapply cas_validate (Lazy.force cas_self, ticket) in
    Eliom_uri.make_string_uri ~absolute:true ~service ()
  in
  let%lwt reply = Ocsigen_http_client.get_url url in
  match reply.Ocsigen_http_frame.frame_content with
  | Some stream ->
     let%lwt info = Ocsigen_stream.(string_of_stream 1000 (get stream)) in
     let%lwt () = Ocsigen_stream.finalize stream `Success in
     return (parse_cas_validation info)
  | None -> return (`Error `Http)

let cas_handler ticket () =
  let%lwt uuid, service, _ =
    match%lwt Eliom_reference.get auth_env with
    | None -> failwith "cas handler was invoked without environment"
    | Some x -> return x
  in
  match ticket with
  | Some x ->
     let%lwt server =
       match%lwt Eliom_reference.get cas_server with
       | None -> failwith "cas handler was invoked without a server"
       | Some x -> return x
     in
     (match%lwt get_cas_validation server x with
     | `Yes (Some name) ->
        let%lwt () = Eliom_reference.set user (Some {uuid; service; name}) in
        default_cont uuid ()
     | `No -> fail_http 401
     | `Yes None | `Error _ -> fail_http 502)
  | None ->
     let%lwt () = Eliom_reference.unset cas_server in
     let%lwt () = Eliom_reference.unset auth_env in
     default_cont uuid ()

let () = Eliom_registration.Any.register ~service:login_cas cas_handler

let cas_login_handler config () =
  match config with
  | [server] ->
     let%lwt () = Eliom_reference.set cas_server (Some server) in
     let cas_login = Eliom_service.extern
       ~prefix:server
       ~path:["login"]
       ~meth:(Eliom_service.Get Eliom_parameter.(string "service"))
       ()
     in
     let service = preapply cas_login (Lazy.force cas_self) in
     Eliom_registration.(Redirection.send (Redirection service))
  | _ -> failwith "cas_login_handler invoked with bad config"

(** OpenID Connect (OIDC) authentication *)

let oidc_state = Eliom_reference.eref ~scope None

let login_oidc = Eliom_service.create
  ~path:(Eliom_service.Path ["auth"; "oidc"])
  ~meth:(Eliom_service.Get Eliom_parameter.any)
  ()

let oidc_self =
  lazy (Eliom_uri.make_string_uri
          ~absolute:true
          ~service:(preapply login_oidc [])
          () |> rewrite_prefix)

let oidc_get_userinfo ocfg info =
  let info = oidc_tokens_of_string info in
  let access_token = info.oidc_access_token in
  let url = ocfg.userinfo_endpoint in
  let headers = Http_headers.(
    add (name "Authorization") ("Bearer " ^ access_token) empty
  ) in
  let%lwt reply = Ocsigen_http_client.get_url ~headers url in
  match reply.Ocsigen_http_frame.frame_content with
  | Some stream ->
     let%lwt info = Ocsigen_stream.(string_of_stream 10000 (get stream)) in
     let%lwt () = Ocsigen_stream.finalize stream `Success in
     let x = oidc_userinfo_of_string info in
     return (Some (match x.oidc_email with Some x -> x | None -> x.oidc_sub))
  | None -> return None

let oidc_get_name ocfg client_id client_secret code =
  let content = [
    "code", code;
    "client_id", client_id;
    "client_secret", client_secret;
    "redirect_uri", Lazy.force oidc_self;
    "grant_type", "authorization_code";
  ] in
  let%lwt reply = Ocsigen_http_client.post_urlencoded_url ~content ocfg.token_endpoint in
  match reply.Ocsigen_http_frame.frame_content with
  | Some stream ->
    let%lwt info = Ocsigen_stream.(string_of_stream 10000 (get stream)) in
    let%lwt () = Ocsigen_stream.finalize stream `Success in
    oidc_get_userinfo ocfg info
  | None -> return None

let oidc_handler params () =
  let%lwt uuid, service, _ =
    match%lwt Eliom_reference.get auth_env with
    | None -> failwith "oidc handler was invoked without environment"
    | Some x -> return x
  in
  let code = try Some (List.assoc "code" params) with Not_found -> None in
  let state = try Some (List.assoc "state" params) with Not_found -> None in
  match code, state with
  | Some code, Some state ->
    let%lwt ocfg, client_id, client_secret, st =
      match%lwt Eliom_reference.get oidc_state with
      | None -> failwith "oidc handler was invoked without a state"
      | Some x -> return x
    in
    let%lwt () = Eliom_reference.unset oidc_state in
    let%lwt () = Eliom_reference.unset auth_env in
    if state <> st then fail_http 401 else
    (match%lwt oidc_get_name ocfg client_id client_secret code with
    | Some name ->
       let%lwt () = Eliom_reference.set user (Some {uuid; service; name}) in
       default_cont uuid ()
    | None -> fail_http 401)
  | _, _ -> default_cont uuid ()

let () = Eliom_registration.Any.register ~service:login_oidc oidc_handler

let get_oidc_configuration server =
  let url = server ^ "/.well-known/openid-configuration" in
  let%lwt reply = Ocsigen_http_client.get_url url in
  match reply.Ocsigen_http_frame.frame_content with
  | Some stream ->
     let%lwt info = Ocsigen_stream.(string_of_stream 10000 (get stream)) in
     let%lwt () = Ocsigen_stream.finalize stream `Success in
     return (oidc_configuration_of_string info)
  | None -> fail_http 404

let split_prefix_path url =
  let n = String.length url in
  let i = String.rindex url '/' in
  String.sub url 0 i, [String.sub url (i+1) (n-i-1)]

let oidc_login_handler config () =
  match config with
  | [server; client_id; client_secret] ->
     let%lwt ocfg = get_oidc_configuration server in
     let%lwt state = generate_token () in
     let%lwt () = Eliom_reference.set oidc_state (Some (ocfg, client_id, client_secret, state)) in
     let prefix, path = split_prefix_path ocfg.authorization_endpoint in
     let auth_endpoint = Eliom_service.extern ~prefix ~path
       ~meth:(Eliom_service.Get Eliom_parameter.(string "redirect_uri" **
           string "response_type" ** string "client_id" **
           string "scope" ** string "state" ** string "prompt"))
       ()
     in
     let service = preapply auth_endpoint
       (Lazy.force oidc_self, ("code", (client_id, ("openid email", (state, "consent")))))
     in
     Eliom_registration.(Redirection.send (Redirection service))
  | _ -> failwith "oidc_login_handler invoked with bad config"

(** Generic authentication *)

let get_login_handler service uuid auth_system config =
  let%lwt () = Eliom_reference.set auth_env (Some (uuid, service, config)) in
  match auth_system with
  | "dummy" -> Web_templates.login_dummy () >>= Eliom_registration.Html.send
  | "cas" -> cas_login_handler config ()
  | "password" -> Web_templates.login_password () >>= Eliom_registration.Html.send
  | "oidc" -> oidc_login_handler config ()
  | _ -> fail_http 404

let login_handler service uuid =
  let myself service =
    match uuid with
    | None -> preapply site_login service
    | Some u -> preapply election_login ((u, ()), service)
  in
  match%lwt Eliom_reference.get user with
  | Some _ ->
     let%lwt () = cont_push (fun () -> Eliom_registration.(Redirection.send (Redirection (myself service)))) in
     Web_templates.already_logged_in () >>= Eliom_registration.Html.send
  | None ->
     let%lwt c = match uuid with
       | None -> return !site_auth_config
       | Some u -> Web_persist.get_auth_config u
     in
     match service with
     | Some s ->
        let%lwt auth_system, config =
          try return @@ List.assoc s c
          with Not_found -> fail_http 404
        in
        get_login_handler s uuid auth_system config
     | None ->
        match c with
        | [s, _] -> Eliom_registration.(Redirection.send (Redirection (myself (Some s))))
        | _ ->
           let builder =
             match uuid with
             | None -> fun s ->
               preapply Web_services.site_login (Some s)
             | Some u -> fun s ->
               preapply Web_services.election_login ((u, ()), Some s)
           in
           Web_templates.login_choose (List.map fst c) builder () >>=
           Eliom_registration.Html.send

let logout_handler () =
  let%lwt () = Eliom_reference.unset Web_state.user in
  match%lwt cont_pop () with
  | Some f -> f ()
  | None -> Eliom_registration.(Redirection.send (Redirection Web_services.home))

let () = Eliom_registration.Any.register ~service:site_login
  (fun service () -> login_handler service None)

let () = Eliom_registration.Any.register ~service:logout
  (fun () () -> logout_handler ())

let () = Eliom_registration.Any.register ~service:election_login
  (fun ((uuid, ()), service) () -> login_handler service (Some uuid))
