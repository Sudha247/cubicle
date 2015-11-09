/**************************************************************************/
/*                                                                        */
/*                              Cubicle                                   */
/*                                                                        */
/*                       Copyright (C) 2011-2015                          */
/*                                                                        */
/*                  Sylvain Conchon and Alain Mebsout                     */
/*                       Universite Paris-Sud 11                          */
/*                                                                        */
/*                                                                        */
/*  This file is distributed under the terms of the Apache Software       */
/*  License version 2.0                                                   */
/*                                                                        */
/**************************************************************************/

%{
  open Options
  open Parsing
  open Format
  open Muparser_globals

%}

%token ENDSTATE EOF
%token <string * string> AFFECTATION
%token <int> STATE                         
/*
%token LEFTSQ RIGHTSQ COLON
%token <string> IDENT
%token <string> INT
*/

%type <unit> states
%start states

%type <unit> state
%start state

%%


states:
  | EOF { () }
  | state_list EOF { () }
;
  
state_list:
  | statenb { () }
  | statenb state_list { () }
;

statenb:
  | STATE { if max_forward <> -1 && $1 > max_forward then
              Unix.kill (Unix.getpid ()) Sys.sigint
    (* printf "%d@." $1 *) }
;
  
state:
  | affectations ENDSTATE { Enumerative.register_state !env !st
    (* Enumerative.print_last !Muparser_globals.env *) }
;

/*
begin_state:
  | STATE { printf "Parsing state %d ...@." $1; new_state () }
;
*/

affectations:
  | affectation { () }
  | affectation affectations { () }
;

/*
value:
  | IDENT { $1 }
  | INT { $1 }
;

var:
  | IDENT { $1 }
  | var LEFTSQ INT RIGHTSQ { $1 ^ "[" ^ $3 ^ "]" }
  | var LEFTSQ IDENT RIGHTSQ { $1 ^ "[" ^ $3 ^ "]" }
;
*/

affectation:
  | AFFECTATION
    { try
        let v, x = $1 in
        (* eprintf "%s -> %s@." v x; *)
        let id_var = Hashtbl.find encoding v in
        let id_value = Hashtbl.find encoding x in
        !st.(id_var) <- id_value
      with Not_found -> ()
    }
  /* less efficient to parse these tokens */
  /*                     
  | var COLON value
    { try
        let id_var = Hashtbl.find encoding $1 in
        let id_value = Hashtbl.find encoding $3 in
        !st.(id_var) <- id_value
      with Not_found -> ()
    }
  */
;


