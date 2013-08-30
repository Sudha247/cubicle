(* This file has been generated from Why3 theory FOL *)
open Ast
open Global
open Format
module S = Set__Fset

open Why3

type t = Term.term
module Caca = Map.Make(Mlw_wp)
(* let compare = Term.compare *)


let rec print = Why3.Pretty.print_term

(* type structure to be defined (uninterpreted type) *)

(* let infix_breq (x: structure) (x1: t) : bool = *)
(*   failwith "to be implemented" (\* uninterpreted symbol *\) *)

let ffalse  : t = Term.t_true

let ttrue  : t = Term.t_false


let declarations_task = ref None


let init_declarations s =
  declarations_task := 
    List.fold_left (fun task (x,y) ->
		    let tys = Ty.create_tysymbol
				(Ident.id_fresh (Hstring.view x))
				[] None in
		    match y with
		    | [] -> Task.add_ty_decl task tys
		    | _ -> 
		       let constrs = 
			 List.map (fun s ->
				   Term.create_lsymbol 
				     (Ident.id_fresh (Hstring.view s))
				     [] None, []) y in
		       Task.add_data_decl task [tys, constrs]
		   ) !declarations_task s.type_defs;
  declarations_task :=
    List.fold_left 
      (fun task (n, t) ->
       let ty = Ty.ty_app (Ty.create_tysymbol
		   (Ident.id_fresh (Hstring.view n))
		   [] None) [] in
       let f = Term.create_fsymbol (Ident.id_fresh (Hstring.view n)) [] ty in
       Task.add_param_decl task f
      ) !declarations_task (s.consts @ s.globals);
  declarations_task :=
    List.fold_left 
      (fun task (n, (args, ret)) ->
       let ty_ret = Ty.ty_app (Ty.create_tysymbol
		   (Ident.id_fresh (Hstring.view ret))
		   [] None) []  in
       let ty_args = List.map (fun t-> Ty.ty_app (Ty.create_tysymbol
		   (Ident.id_fresh (Hstring.view t))
		   [] None) []) args in
       let f = Term.create_fsymbol (Ident.id_fresh (Hstring.view n))
				   ty_args ty_ret in
       Task.add_param_decl task f
      ) !declarations_task s.arrays



	
(* neg *)  
let prefix_tl (x: t) : t = Term.t_not_simp x

let infix_et (x: t) (x1: t) : t = Term.t_and_simp x x1

let infix_plpl (x: t) (x1: t) : t = Term.t_or_simp x x1

let infix_eqgt (x: t) (x1: t) : t = Term.t_implies_simp x x1


let infix_breqeq (x: t) (x1: t) : bool =
  if Options.debug then eprintf "do: %a  |=  %a@." print x print x1;

  let f = infix_eqgt x x1 in

  let goal_id = Decl.create_prsymbol (Ident.id_fresh "goal") in
  let task = Task.add_prop_decl !declarations_task Decl.Pgoal goal_id f in

  assert false

(* Notataions *)

let neg = prefix_tl

let (&) x x1 = infix_et x x1

let (++) x x1 = infix_plpl x x1

let (=>) x x1 = infix_eqgt x x1
  
let (|=) x x1 = infix_breqeq x x1

module HSet = Hstring.HSet

let sat (f: t) : bool = assert false

let valid (f: t) : bool = not (sat (prefix_tl f))
