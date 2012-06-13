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

exception ReachBound

type op_comp = Eq | Lt | Le | Neq
type op_arith = Plus | Minus

type sort = Glob | Arr | Constr | Var

type const = ConstInt of Num.num | ConstReal of Num.num | ConstName of Hstring.t

module MConst : sig 
  include Map.S with type key = const
  val choose : int t -> key * int
end

val compare_constants : int MConst.t -> int MConst.t -> int

type term = 
  | Const of int MConst.t
  | Elem of Hstring.t * sort
  | Access of Hstring.t * Hstring.t * sort
  | Arith of Hstring.t * sort * int MConst.t

val compare_term : term -> term -> int

type acc_eq = { a : Hstring.t; i: Hstring.t; e: term }

module rec Atom : sig
  type t =
    | True
    | False
    | Comp of term * op_comp * term
    | Ite of SAtom.t * t * t

  val compare : t -> t -> int
end 
and SAtom : Set.S with type elt = Atom.t

val proc_vars : Hstring.t list
val alpha_vars : Hstring.t list
val fresh_vars : Hstring.t list

val add : Atom.t -> SAtom.t -> SAtom.t
val svar : (Hstring.t * Hstring.t) list -> Hstring.t -> Hstring.t
val subst_term : (Hstring.t * Hstring.t) list ->
  ?sigma_sort:(sort * sort) list -> term -> term
val subst_atom : (Hstring.t * Hstring.t) list ->
  ?sigma_sort:(sort * sort) list -> Atom.t -> Atom.t
val subst_atoms : (Hstring.t * Hstring.t) list ->
  ?sigma_sort:(sort * sort) list -> SAtom.t -> SAtom.t
val build_subst : Hstring.t list -> Hstring.t list -> 
  (Hstring.t * Hstring.t) list

module TimerSubset : Timer.S
module TimerApply  : Timer.S

module ArrayAtom : sig
  type t = Atom.t array
  val equal : t -> t -> bool
  val subset : t -> t -> bool
  val of_satom : SAtom.t -> t
  val union : t -> t -> t
  val apply_subst : (Hstring.t * Hstring.t) list -> t -> t
  val nb_diff : t -> t -> int
  val compare_nb_diff : t -> t -> t -> int
  val compare_nb_common : t -> t -> t -> int
  val diff : t -> t -> t
  val alpha : t -> Hstring.t list -> Hstring.t list * t
end

type update = {
  up_arr : Hstring.t;
  up_arg : Hstring.t;
  up_swts : (SAtom.t * term) list;
}

type transition = {
  tr_name : Hstring.t;
  tr_args : Hstring.t list;
  tr_reqs : SAtom.t;
  tr_ureq : (Hstring.t * SAtom.t list) list;
  tr_assigns : (Hstring.t * term) list;
  tr_upds : update list;
  tr_nondets : Hstring.t list;
}

type elem = Hstring.t * (Hstring.t list)

type system = {
  globals : (Hstring.t * Hstring.t) list;
  consts : (Hstring.t * Hstring.t) list;
  arrays : (Hstring.t * (Hstring.t * Hstring.t)) list;
  type_defs : elem list;
  init : Hstring.t option * SAtom.t;
  invs : (Hstring.t list * SAtom.t) list;
  unsafe : (Hstring.t list * SAtom.t) list;
  trans : transition list
}

(* Types AST *)
 
type t_system = {
  t_from : (Hstring.t * Hstring.t list * t_system) list;
  t_init : Hstring.t option * SAtom.t;
  t_invs : (Hstring.t list * SAtom.t) list;
  t_unsafe : Hstring.t list * SAtom.t;
  t_arru : ArrayAtom.t;
  t_alpha : Hstring.t list * ArrayAtom.t;
  t_trans : transition list;
  mutable t_deleted : bool;
  t_nb : int;
  t_nb_father : int;
  t_glob_proc : Hstring.t list;
}

val declared_terms : ArrayAtom.t -> bool
