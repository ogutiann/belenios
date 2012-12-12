open Eliom_service
open Eliom_parameter

let project_home = external_service
  ~prefix:"http://heliosvoting.org"
  ~path:[]
  ~get_params:unit
  ()

let home = service
  ~path:[]
  ~get_params:unit
  ()

let elections_administered = service
  ~path:["elections"; "administered"]
  ~get_params:unit
  ()

let election_new = service
  ~path:["elections"; "new"]
  ~get_params:unit
  ()

let election_shortcut = service
  ~path:["e"]
  ~get_params:(suffix (string "name"))
  ()

let login = service
  ~path:["login"]
  ~get_params:unit
  ()