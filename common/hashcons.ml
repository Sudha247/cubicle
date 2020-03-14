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

(*s Hash tables for hash-consing. (Some code is borrowed from the ocaml
    standard library, which is copyright 1996 INRIA.) *)

module type HashedType =
  sig
    type t
    val equal : t -> t -> bool
    val hash : t -> int
    val tag : int -> t -> t
  end

module type S =
  sig
    type t
    val hashcons : t -> t
    val iter : (t -> unit) -> unit
    val stats : unit -> int * int * int * int * int * int
  end

module Make(H : HashedType) : (S with type t = H.t) =
struct
  type t = H.t

  module WH = Weak.Make (H)

  (* XXX KC: Hack *)
  let next_tag_arr = Array.init 128 (fun _ -> ref 0)

  (* XXX KC: Hack *)
  let htable_arr  = Array.init 128 (fun _ -> WH.create 5003)

  let hashcons d =
    let self :> int = Domain.self () in
    let self = self mod 128 in
    let next_tag = next_tag_arr.(self) in
    let htable = htable_arr.(self) in
    let d = H.tag !next_tag d in
    let o = WH.merge htable d in
    if o == d then incr next_tag;
    o

  let iter f =
    let self :> int = Domain.self () in
    let self = self mod 128 in
    WH.iter f htable_arr.(self)

  let stats () =
    let self :> int = Domain.self () in
    let self = self mod 128 in
    WH.stats htable_arr.(self)
end

let combine acc n = n * 65599 + acc
let combine2 acc n1 n2 = combine acc (combine n1 n2)
let combine3 acc n1 n2 n3 = combine acc (combine n1 (combine n2 n3))
let combine_list f = List.fold_left (fun acc x -> combine acc (f x))
let combine_option h = function None -> 0 | Some s -> (h s) + 1
let combine_pair h1 h2 (a1,a2) = combine (h1 a1) (h2 a2)

type 'a hash_consed = {
  tag : int;
  node : 'a }

module type HashedType_consed =
  sig
    type t
    val equal : t -> t -> bool
    val hash : t -> int
  end

module type S_consed =
  sig
    type key
    val hashcons : key -> key hash_consed
    val iter : (key hash_consed -> unit) -> unit
    val stats : unit -> int * int * int * int * int * int
  end

module Make_consed(H : HashedType_consed) : (S_consed with type key = H.t) =
struct
  module M = Make(struct
    type t = H.t hash_consed
    let hash x = H.hash x.node
    let equal x y = H.equal x.node y.node
    let tag i x = {x with tag = i}
  end)
  include M
  type key = H.t
  let hashcons x = M.hashcons {tag = -1; node = x}
end
