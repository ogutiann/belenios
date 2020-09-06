(**************************************************************************)
(*                                BELENIOS                                *)
(*                                                                        *)
(*  Copyright © 2012-2020 Inria                                           *)
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

let lang = "fr"
let booth_step6 = "Étape 6/6 : "
let has_been_accepted = " a été accepté."
let you_can_check_its_presence = "Vous pouvez vérifier sa présence dans l'"
let ballot_box = "urne"
let anytime_during_the_election = " à tout moment pendant l'élection."
let confirmation_email = " Un e-mail de confirmation vous a été envoyé."
let thank_you_for_voting = "Merci pour votre participation !"
let is_rejected_because = " est refusé, parce que "
let fail = "ÉCHEC !"
let accepted_ballots = "Bulletins acceptés"
let ballots_have_been_accepted_so_far = " bulletin(s) ont été accepté(s) jusqu'à présent."
let ballots_have_been_accepted = " bulletin(s) ont été accepté(s)."
let ballots_have_been_accepted_and = " bulletin(s) ont été accepté(s), et "
let have_been_tallied = " ont été compté(s)."
let username = "Nom d'utilisateur :"
let password = "Mot de passe :"
let login = "Se connecter"
let password_login = "Connexion par mot de passe"
let not_found = "Non trouvé"
let election_does_not_exist = "Cette élection n'existe pas. Cela peut arriver quand l'élection n'a pas encore été ouverte ou a été supprimée."
let cookies_are_blocked = "Les cookies sont bloqués"
let please_enable_them = "Votre navigateur semble bloquer les cookies. Veuillez les activer."


let mail_password_subject : ('a, 'b, 'c, 'd, 'e, 'f) format6 =
  "Votre mot de passe pour l'élection %s"

let mail_password : ('a, 'b, 'c, 'd, 'e, 'f) format6 =
  "Vous êtes enregistré(e) en tant qu'électeur(trice) pour l'élection

  %s

Veuillez trouver ci-dessous votre nom d'utilisateur et votre mot de
passe. Pour soumettre un bulletin, vous aurez également besoin d'un
code de vote, envoyé dans un e-mail séparé. Soyez attentif(ve), le mot
de passe et le code de vote se ressemblent mais jouent des rôles
différents. Le système vous demandera votre code de vote dès l'entrée
dans l'isoloir virtuel. Le nom d'utilisateur et le mot de passe sont
nécessaires lorsque votre bulletin est prêt à être soumis.

Nom d'utilisateur : %s
Mot de passe : %s
Page de l'élection : %s

Notez que vous pouvez voter plusieurs fois. Seul le dernier vote est
pris en compte.%s"


let mail_credential_subject : ('a, 'b, 'c, 'd, 'e, 'f) format6 =
  "Votre code de vote pour l'élection %s"

let mail_credential : ('a, 'b, 'c, 'd, 'e, 'f) format6 =
  "Vous êtes enregistré(e) en tant qu'électeur(trice) pour l'élection

  %s

%s

Code de vote : %s
Page de l'élection : %s

Notez que vous pouvez voter plusieurs fois. Seul le dernier vote est
pris en compte.%s"

let mail_credential_password =
"Veuillez trouver ci-dessous votre code de vote. Pour soumettre un
bulletin, vous aurez également besoin d'un mot de passe, envoyé dans
un e-mail séparé. Soyez attentif(ve), le mot de passe et le code de
vote se ressemblent mais jouent des rôles différents. Le système vous
demandera votre code de vote dès l'entrée dans l'isoloir virtuel. Le
nom d'utilisateur et le mot de passe sont nécessaires lorsque votre
bulletin est prêt à être soumis."

let mail_credential_cas =
"Veuillez trouver ci-dessous votre code de vote."

let mail_confirmation_subject : ('a, 'b, 'c, 'd, 'e, 'f) format6 =
  "Votre vote pour l'élection %s"

let mail_confirmation : ('a, 'b, 'c, 'd, 'e, 'f) format6 =
  "%s,

Votre vote pour l'élection

  %s

a été enregistré. Votre numéro de suivi est

  %s%s


Vous pouvez vérifier sa présence dans l'urne, accessible au
  %s

Les résultats seront publiés sur la page de l'élection
  %s%s

-- \nBelenios"

let this_vote_replaces = "\n\nCe vote remplace le vote précédent."
let please_contact = "Pour obtenir plus d'informations, veuillez contacter :"

let error_Serialization : ('a, 'b, 'c, 'd, 'e, 'f) format6 = "votre bulletin a une erreur de syntaxe (%s)"
let error_ProofCheck = "certaines preuves sont invalides"
let error_ElectionClosed = "l'élection est fermée"
let error_MissingCredential = "un code de vote manque"
let error_InvalidCredential = "votre code de vote est invalide"
let error_RevoteNotAllowed = "vous n'êtes pas autorisé(e) à revoter"
let error_ReusedCredential = "votre code de vote a déjà été utilisé"
let error_WrongCredential = "vous n'êtes pas autorisé(e) à voter avec ce code de vote"
let error_UnauthorizedVoter = "vous n'êtes pas autorisé(e) a voter"
