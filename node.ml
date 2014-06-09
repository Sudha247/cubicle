(**************************************************************************)
(*                                                                        *)
(*                              Cubicle                                   *)
(*                                                                        *)
(*                       Copyright (C) 2011-2014                          *)
(*                                                                        *)
(*                  Sylvain Conchon and Alain Mebsout                     *)
(*                       Universite Paris-Sud 11                          *)
(*                                                                        *)
(*                                                                        *)
(*  This file is distributed under the terms of the Apache Software       *)
(*  License version 2.0                                                   *)
(*                                                                        *)
(**************************************************************************)

open Format
open Options
open Ast
open Util
open Types

type t = node_cube


let variables {cube = {Cube.vars = vars }} = vars 

let array n = n.cube.Cube.array

let litterals n = n.cube.Cube.litterals

let dim n = Cube.dim n.cube

let size n = Cube.size n.cube


let compare_kind s1 s2 =
  match s1.kind, s2.kind with
  | Approx, Approx -> 0
  | Approx, _ -> -1
  | _, Approx -> 1
  | k1, k2 -> Pervasives.compare k1 k2

let compare_by_breadth s1 s2 =
  let v1 = dim s1 in
  let v2 = dim s2 in
  let c = Pervasives.compare v1 v2 in
  if c <> 0 then c else
    let c1 = size s1 in
    let c2 = size s2 in
    let c = Pervasives.compare c1 c2 in
    if c <> 0 then c else
      let c =  compare_kind s1 s2 in
      if c <> 0 then c else
        let c = Pervasives.compare s1.depth s2.depth in 
        if c <> 0 then c else
          Pervasives.compare (abs s1.tag) (abs s2.tag)

let compare_by_depth  s1 s2 =
  let v1 = dim s1 in
  let v2 = dim s2 in
  let c = Pervasives.compare v1 v2 in
  if c <> 0 then c else
    let c1 = size s1 in
    let c2 = size s2 in
    let c = Pervasives.compare c1 c2 in
    if c <> 0 then c else
      let c =  compare_kind s1 s2 in
      if c <> 0 then c else
        let c = Pervasives.compare s2.depth s1.depth in 
        if c <> 0 then c else
          Pervasives.compare (abs s1.tag) (abs s2.tag)

let rec origin n = match n.from with
  | [] -> n
  | (_,_, p)::_ ->
     if p.kind = Approx then p
     else origin p

let new_tag =
  let cpt_pos = ref 0 in
  let cpt_neg = ref 0 in
  fun ?(kind=Node) () -> 
  match kind with 
  | Approx -> decr cpt_neg; !cpt_neg
  | _ -> incr cpt_pos; !cpt_pos


let create ?(kind=Node) ?(from=None) cube =
  let hist =  match from with
    | None -> []
    | Some ((tr, args, n) as f) -> f :: n.from in
  { 
    cube = cube;
    tag = new_tag ~kind ();
    kind = kind;
    depth = List.length hist;
    deleted = false;
    from = hist;
  }

let has_deleted_ancestor n =
  let rec has acc = function
    | [] -> false, acc
    | (_, _, a) :: r ->
       if a.deleted then true, acc
       else has (a :: acc) r
  in
  let del, children = has [] n.from in
  if del then List.iter (fun a -> a.deleted <- true) children;
  del
    
let has_deleted_ancestor n =
  List.exists (fun (_, _, a) -> a.deleted) n.from

let ancestor_of n s =
  (* not (List.exists (fun (_,anc) -> n == anc) s.t_from) *)
  (* List.exists (fun (_,_,anc) -> ArrayAtom.equal n.t_arru anc.t_arru) s.t_from *)
  List.exists (fun (_, _, ps) -> n.tag = ps.tag) s.from


let subset n1 n2 = ArrayAtom.subset (array n1) (array n2)
       
let print fmt n = Cube.print fmt n.cube


let print_history fmt n =
  let last = List.fold_left 
    (fun last (tr, args, a) ->
      if dmcmt then 
	fprintf fmt "[%a%a]" Hstring.print tr.tr_name Variable.print_vars args
      else 
	fprintf fmt "%a(%a) ->@ " Hstring.print tr.tr_name
                Variable.print_vars args;
      a
    ) n n.from in
  if dmcmt then fprintf fmt "[0]  "
  else
    if last.kind = Approx then 
      fprintf fmt "@{<fg_blue>approx[%d]@}" last.tag
    else 
      fprintf fmt "@{<fg_magenta>unsafe[%d]@}" last.tag
