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

open Format
open Ast
open Atom
open Options

module T = Smt.Term
module F = Smt.Formula

module TimeF = Timer.Make(struct end)


let proc_terms =
  List.iter 
    (fun x -> Smt.Typing.declare_name x [] Smt.Typing.type_proc) proc_vars;
  List.map (fun x -> T.make_app x []) proc_vars

let distinct_vars = 
  let t = Array.create max_proc F.vrai in
  let _ = 
    List.fold_left 
      (fun (acc,i) v -> 
	 if i<>0 then t.(i) <- F.make_lit F.Neq (v::acc);
	 v::acc, i+1) 
      ([],0) proc_terms 
  in
  function n -> if n = 0 then F.vrai else t.(n-1)

let order_vars =
  let t = Array.create max_proc F.vrai in
  let _ =
    List.fold_left
      (fun (acc, lf, i) v ->
        match acc with
          | v2::r ->
            let lf = (F.make_lit F.Lt [v;v2]) :: lf in
            t.(i) <- F.make F.And lf;
            v::acc, lf, i+1
          | [] -> v::acc, lf, i+1)
      ([], [], 0) proc_terms
  in
  function n -> if n = 0 then F.vrai else t.(n-1)


let make_op_arith = function Plus -> T.Plus | Minus -> T.Minus
let make_op_comp = function
  | Eq -> F.Eq
  | Lt -> F.Lt
  | Le -> F.Le
  | Neq -> F.Neq

let make_const = function
  | ConstInt i -> T.make_int i
  | ConstReal i -> T.make_real i
  | ConstName n -> T.make_app n []

let ty_const = function
  | ConstInt _ -> Smt.Typing.type_int
  | ConstReal _ -> Smt.Typing.type_real
  | ConstName n -> snd (Smt.Typing.find n)

let rec mult_const tc c i =
 match i with
  | 0 -> 
    if ty_const c = Smt.Typing.type_int then T.make_int (Num.Int 0)
    else T.make_real (Num.Int 0)
  | 1 -> tc
  | -1 -> T.make_arith T.Minus (mult_const tc c 0) tc
  | i when i > 0 -> T.make_arith T.Plus (mult_const tc c (i - 1)) tc
  | i when i < 0 -> T.make_arith T.Minus (mult_const tc c (i + 1)) tc
  | _ -> assert false

let make_arith_cs =
  MConst.fold 
    (fun c i acc ->
      let tc = make_const c in
      let tci = mult_const tc c i in
       T.make_arith T.Plus acc tci)

let make_cs cs =
  let c, i = MConst.choose cs in
  let t_c = make_const c in
  let r = MConst.remove c cs in
  if MConst.is_empty r then mult_const t_c c i
  else make_arith_cs r (mult_const t_c c i)
	 
let make_term = function
  | Elem (e, _) -> T.make_app e []
  | Const cs -> make_cs cs 
  | Access (a, i, _) -> T.make_app a [T.make_app i []]
  | Arith (x, _, cs) -> 
      let tx = T.make_app x [] in
      make_arith_cs cs tx

let rec make_formula_set sa = 
  F.make F.And (SAtom.fold (fun a l -> make_literal a::l) sa [])

and make_literal = function
  | True -> F.vrai 
  | False -> F.faux
  | Comp (x, op, y) ->
      let tx = make_term x in
      let ty = make_term y in
      F.make_lit (make_op_comp op) [tx; ty]
  | Ite (la, a1, a2) -> 
      let f = make_formula_set la in
      let a1 = make_literal a1 in
      let a2 = make_literal a2 in
      let ff1 = F.make F.Imp [f; a1] in
      let ff2 = F.make F.Imp [F.make F.Not [f]; a2] in
      F.make F.And [ff1; ff2]

let make_formula atoms =
  F.make F.And (Array.fold_left (fun l a -> make_literal a::l) [] atoms)

let contain_arg z = function
  | Elem (x, _) | Arith (x, _, _) -> Hstring.equal x z
  | Access (x, y, _) -> Hstring.equal y z
  | Const _ -> false

let has_var z = function
  | True | False -> false
  | Comp (t1, _, t2) -> (contain_arg z t1) || (contain_arg z t2)
  | Ite _ -> assert false

let make_init {t_init = arg, sa } lvars =
  match arg with
    | None ->   
	make_formula_set sa
    | Some z ->
	let sa, cst = SAtom.partition (has_var z) sa in
	let f = make_formula_set cst in
	let fsa = 
	  List.rev_map
	    (fun h -> make_formula_set (subst_atoms [z, h] sa)) lvars
	in
	F.make F.And (f::fsa)

let unsafe ({ t_unsafe = (args, sa) } as ts) =
  Smt.clear ();
  Smt.assume ~profiling (F.Ground (distinct_vars (List.length args)));
  (* Smt.assume (order_vars (List.length args)); *)
  if profiling then TimeF.start ();
  let init = F.Ground (make_init ts (List.rev_append ts.t_glob_proc args)) in
  let f = F.Ground (make_formula_set sa) in
  if profiling then TimeF.pause ();
  if debug_smt then eprintf "[smt] safety: %a and %a@." F.print f F.print init;
  Smt.assume ~profiling init;
  Smt.assume ~profiling f;
  Smt.check ~profiling


let assume_goal {t_unsafe = (args, _); t_arru = ap } =
  Smt.clear ();
  Smt.assume ~profiling (F.Ground (distinct_vars (List.length args)));
  (* Smt.assume (order_vars (List.length args)); *)
  if profiling then TimeF.start ();
  let f = F.Ground (make_formula ap) in
  if profiling then TimeF.pause ();
  if debug_smt then eprintf "[smt] goal g: %a@." F.print f;
  Smt.assume ~profiling f;
  Smt.check ~profiling

let assume_node ap =
  if profiling then TimeF.start ();
  let f = F.Ground (F.make F.Not [make_formula ap]) in
  if profiling then TimeF.pause ();
  if debug_smt then eprintf "[smt] assume node: %a@." F.print f;
  Smt.assume ~profiling f;
  Smt.check ~profiling
