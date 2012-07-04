(**************************************************************************)
(*                                                                        *)
(*                                  Cubicle                               *)
(*             Combining model checking algorithms and SMT solvers        *)
(*                                                                        *)
(*                  Sylvain Conchon and Alain Mebsout                     *)
(*                  Universite Paris-Sud 11                               *)
(*                                                                        *)
(*  Copyright 2011. This file is distributed under the terms of the       *)
(*  Apache Software License version 2.0                                   *)
(*                                                                        *)
(**************************************************************************)

{
  open Lexing
  open Parser

  let keywords = Hashtbl.create 97
  let () = 
    List.iter 
      (fun (x,y) -> Hashtbl.add keywords x y)
      [ "type", TYPE;
	"init", INIT;
	"transition", TRANSITION;
	"invariant", INVARIANT;
	"requires", REQUIRE;
	"uguard", UGUARD;
	"assign", ASSIGN;
        "array", ARRAY;
        "var", VAR;
        "const", CONST;
        "unsafe", UNSAFE;
	"case", CASE;
	"forall_other", FORALL;
      ]
	       
  let newline lexbuf =
    let pos = lexbuf.lex_curr_p in
    lexbuf.lex_curr_p <- 
      { pos with pos_lnum = pos.pos_lnum + 1; pos_bol = pos.pos_cnum }

  let num_of_stringfloat s =
    let r = ref (Num.Int 0) in
    let code_0 = Char.code '0' in
    let num10 = Num.Int 10 in
    let pos_dot = ref (-1) in
    for i=0 to String.length s - 1 do
      let c = s.[i] in
      if c = '.' then pos_dot := i 
      else
	r := Num.add_num (Num.mult_num num10 !r) 
	  (Num.num_of_int (Char.code s.[i] - code_0))
    done;
    assert (!pos_dot <> -1);
    Num.div_num !r (Num.power_num num10 (Num.num_of_int !pos_dot))
    

  let string_buf = Buffer.create 1024

  exception Lexical_error of string


}

let newline = '\n'
let space = [' ' '\t' '\r']
let integer = ['0' - '9'] ['0' - '9']*
let real = ['0' - '9'] ['0' - '9']* '.' ['0' - '9']* 
let mident = ['A'-'Z']['a'-'z' 'A'-'Z' '0'-'9' '_']*
let lident = ['a'-'z']['a'-'z' 'A'-'Z' '0'-'9' '_']*

rule token = parse
  | newline 
      { newline lexbuf; token lexbuf }
  | space+  
      { token lexbuf }
  | lident as id
      { try Hashtbl.find keywords id
	with Not_found -> LIDENT id }
  | mident as id { MIDENT id }
  | real as r { REAL (num_of_stringfloat r) }
  | integer as i { INT (Num.num_of_string i) }
  | "("
      { LEFTPAR }
  | ")"
      { RIGHTPAR }
  | "."
      { DOT }
  | "+"
      { PLUS }
  | "-"
      { MINUS }
  | ":"
      { COLON }
  | "="
      { EQ }
  | ":="
      { AFFECT }
  | "<>"
      { NEQ }
  | "<"
      { LT }
  | "<="
      { LE }
  | "["
      { LEFTSQ }
  | "]"
      { RIGHTSQ }
  | "{"
      { LEFTBR }
  | "}"
      { RIGHTBR }
  | "||"
      { OR }
  | "|"
      { BAR }
  | ","
      { COMMA }
  | ";"
      { PV }
  | '_'
      { UNDERSCORE }
  | "&&"
      { AND }
  | "(*"
      { comment lexbuf; token lexbuf }
  | eof 
      { EOF }
  | _ as c
      { raise (Lexical_error ("illegal character: " ^ String.make 1 c)) }

and comment = parse
  | "*)" 
      { () }
  | "(*" 
      { comment lexbuf; comment lexbuf }
  | eof
      { raise (Lexical_error "unterminated comment") }
  | newline 
      { newline lexbuf; comment lexbuf }
  | _ 
      { comment lexbuf }