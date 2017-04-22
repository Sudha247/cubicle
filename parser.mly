/**************************************************************************/
/*                                                                        */
/*                              Cubicle                                   */
/*                                                                        */
/*                       Copyright (C) 2011-2014                          */
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

  open Ast
  open Types
  open Parsing
  open Ptree
  
  let _ = Smt.set_cc false; Smt.set_arith false; Smt.set_sum false


  (* Helper functions for location info *)

  let loc () = (symbol_start_pos (), symbol_end_pos ())
  let loc_i i = (rhs_start_pos i, rhs_end_pos i)
  let loc_ij i j = (rhs_start_pos i, rhs_end_pos j)

  type t = 
    | Assign of Hstring.t * pglob_update
    | Nondet of Hstring.t
    | Upd of pupdate
    | Write of Variable.t option * Hstring.t * Variable.t list * pglob_update

  module S = Set.Make(Hstring)

  module Constructors = struct
    let s = ref (S.add (Hstring.make "True") 
		   (S.singleton (Hstring.make "False")))
    let add x = s := S.add x !s
    let mem x = S.mem x !s
  end

  module Globals = struct
    let s = ref S.empty
    let add x = s := S.add x !s
    let mem x = S.mem x !s
  end

  module Arrays = struct
    let s = ref S.empty
    let add x = s := S.add x !s
    let mem x = S.mem x !s
  end

  module Consts = struct
    let s = ref S.empty
    let add x = s := S.add x !s
    let mem x = S.mem x !s
  end

  module Weaks = struct
    let s = ref S.empty
    let add x = s := S.add x !s
    let mem x = S.mem x !s
  end

  let sort s = 
    if Constructors.mem s then Constr 
    else if Globals.mem s then Glob
    else
      begin
        assert (not (Arrays.mem s));
        Var
      end

  let is_weak s = Weaks.mem s

  let hNone = Hstring.make ""
 
  let rec process_read_term fn = function
  | Read (p, v, vi) -> fn p v vi
  | Arith (t, c) -> Arith (process_read_term fn t, c)
  | t -> t

  let rec process_read_atom fn = function
  | Atom.Comp (t1, op, t2) ->
     Atom.Comp (process_read_term fn t1, op, process_read_term fn t2)
  | Atom.Ite (sa, a1, a2) ->
     Atom.Ite (SAtom.fold (fun a sa ->
       SAtom.add (process_read_atom fn a) sa) sa SAtom.empty,
       process_read_atom fn a1, process_read_atom fn a2)
  | t -> t

  let process_read_pterm fn = function
  | TTerm t -> TTerm (process_read_term fn t)
  | t -> t

  let process_read_patom fn = function
  | AAtom a -> AAtom (process_read_atom fn a)
  | AEq (t1, t2) -> AEq (process_read_pterm fn t1, process_read_pterm fn t2)
  | ANeq (t1, t2) -> ANeq (process_read_pterm fn t1, process_read_pterm fn t2)
  | ALe (t1, t2) -> ALe (process_read_pterm fn t1, process_read_pterm fn t2)
  | ALt (t1, t2) -> ALt (process_read_pterm fn t1, process_read_pterm fn t2)
  | t -> t

  let rec process_read_pform fn = function
  | PAtom a -> PAtom (process_read_patom fn a)
  | PNot f -> PNot (process_read_pform fn f)
  | PAnd fl -> PAnd (List.map (process_read_pform fn) fl)
  | POr fl -> POr (List.map (process_read_pform fn) fl)
  | PImp (f1, f2) -> PImp (process_read_pform fn f1, process_read_pform fn f2)
  | PEquiv (f1, f2) ->
     PEquiv (process_read_pform fn f1, process_read_pform fn f2)
  | PIte (f1, f2, f3) ->
     PIte (process_read_pform fn f1, process_read_pform fn f2,
           process_read_pform fn f3)
  | PForall (vl, f) -> PForall (vl, process_read_pform fn f)
  | PExists (vl, f) -> PExists (vl, process_read_pform fn f)
  | PForall_other (vl, f) -> PForall_other (vl, process_read_pform fn f)
  | PExists_other (vl, f) -> PExists_other (vl, process_read_pform fn f)

  let process_read_pswts fn s =
    List.map (fun (f, t) -> process_read_pform fn f, process_read_pterm fn t) s

  let process_read_pgu fn = function
  | PUTerm t -> PUTerm (process_read_pterm fn t)
  | PUCase s -> PUCase (process_read_pswts fn s)

  let fix_thr t p v vi =
    let pdef = not (Hstring.equal p hNone) in
    match pdef, t with
    | false, Some t -> Read (t, v, vi)
    | true, None -> Read (p, v, vi)
    | false, None -> failwith "No thread in read"
    | true, Some t -> if Hstring.equal p t then Read (p, v, vi)
                      else failwith "Threads differ in read"

  let fix_rd_upd t upd =
    { upd with pup_swts = process_read_pswts (fix_thr t) upd.pup_swts }

  let fix_rd_assign t (v, pgu) =
    (v, process_read_pgu (fix_thr t) pgu)

  let fix_rd_write t (p, v, vi, pgu) =
    let pgu = process_read_pgu (fix_thr t) pgu in
    match p, t with
    | None, Some p -> (p, v, vi, pgu)
    | Some p, None -> (p, v, vi, pgu)
    | None, None -> failwith "No thread in write"
    | Some p, Some q ->
       if Hstring.equal p q then (p, v, vi, pgu)
       else failwith "Threads differ in write"

  let fix_rd_expr t expr =
    process_read_pform (fix_thr t) expr

  let fix_rd_init expr =
    process_read_pform (fun p v vi ->
      if Hstring.equal p hNone then
        match vi with
        | [] -> Elem (v, Glob)
        | _ -> Access (v, vi)
      else
        failwith "Thread not allowed in init"
    ) expr
                       
  let hproc = Hstring.make "proc"
  let hreal = Hstring.make "real"
  let hint = Hstring.make "int"

  let set_from_list = List.fold_left (fun sa a -> SAtom.add a sa) SAtom.empty 

  let fresh_var = 
    let cpt = ref 0 in
    fun () -> incr cpt; Hstring.make ("_j"^(string_of_int !cpt))

%}

%token VAR ARRAY CONST TYPE INIT TRANSITION INVARIANT CASE
%token FORALL EXISTS FORALL_OTHER EXISTS_OTHER
%token SIZEPROC
%token REQUIRE UNSAFE PREDICATE WRITE READ FENCE WEAK
%token OR AND COMMA PV DOT QMARK IMP EQUIV
%token <string> CONSTPROC
%token <string> LIDENT
%token <string> MIDENT
%token LEFTPAR RIGHTPAR COLON EQ NEQ LT LE GT GE
%token LEFTSQ RIGHTSQ LEFTBR RIGHTBR BAR 
%token <Num.num> REAL
%token <Num.num> INT
%token PLUS MINUS TIMES
%token IF THEN ELSE NOT
%token TRUE FALSE
%token UNDERSCORE AFFECT
%token EOF

%nonassoc prec_forall prec_exists
%right IMP EQUIV  
%right OR
%right AND
%nonassoc prec_ite
/* %left prec_relation EQ NEQ LT LE GT GE */
/* %left PLUS MINUS */
%nonassoc NOT
/* %left BAR */

%type <Ast.system> system
%start system
%%

system:
size_proc
type_defs
symbold_decls
decl_list
EOF
{ let ptype_defs = $2 in
  let pconsts, pglobals, parrays = $3 in
  psystem_of_decls ~pglobals ~pconsts ~parrays ~ptype_defs $4
   |> encode_psystem 
}
;

decl_list :
  | decl { [$1] }
  | decl decl_list { $1 :: $2 }
;

decl :
  | init { let l, p, e = $1 in PInit (l, p, fix_rd_init e) }
  | invariant { let l, p, e = $1 in PInv (l, p, fix_rd_expr None e) }
  | unsafe { let l, p, e = $1 in PUnsafe (l, p, fix_rd_expr None e) }
  | transition { PTrans $1 }
  | function_decl { PFun  }

symbold_decls :
  | { [], [], [] }
  | const_decl symbold_decls
      { let consts, vars, arrays = $2 in ($1::consts), vars, arrays }
  | var_decl symbold_decls
      { let consts, vars, arrays = $2 in consts, ($1::vars), arrays }
  | array_decl symbold_decls
      { let consts, vars, arrays = $2 in consts, vars, ($1::arrays) }
;

function_decl :
  | PREDICATE lident LEFTPAR lident_comma_list RIGHTPAR LEFTBR expr RIGHTBR {
    add_fun_def $2 $4 $7
  }
;

weak_opt:
  | /*epsilon*/ { false }
  | WEAK { true }

var_decl:
  | weak_opt VAR mident COLON lident { 
    if Hstring.equal $5 hint || Hstring.equal $5 hreal then Smt.set_arith true;
    Globals.add $3; if $1 then Weaks.add $3;
    loc (), $3, $5, $1 }
;

const_decl:
  | CONST mident COLON lident { 
    if Hstring.equal $4 hint || Hstring.equal $4 hreal then Smt.set_arith true;
    Consts.add $2;
    loc (), $2, $4 }
;

array_decl:
  | weak_opt ARRAY mident LEFTSQ lident_list_plus RIGHTSQ COLON lident { 
        if not (List.for_all (fun p -> Hstring.equal p hproc) $5) then
	  raise Parsing.Parse_error;
	if Hstring.equal $8 hint || Hstring.equal $8 hreal then Smt.set_arith true;
	Arrays.add $3; if $1 then Weaks.add $3;
	loc (), $3, ($5, $8), $1 }
;

type_defs:
  | { [] }
  | type_def_plus { $1 }
;

type_def_plus:
  | type_def { [$1] }
  | type_def type_def_plus { $1::$2 }
;

size_proc:
  | { () }
  | SIZEPROC INT { Options.size_proc := Num.int_of_num $2 }
;
      
type_def:
  | TYPE lident { (loc (), ($2, [])) }
  | TYPE lident EQ constructors 
      { Smt.set_sum true; List.iter Constructors.add $4; (loc (), ($2, $4)) }
  | TYPE lident EQ BAR constructors 
      { Smt.set_sum true; List.iter Constructors.add $5; (loc (), ($2, $5)) }
;

constructors:
  | mident { [$1] }
  | mident BAR constructors { $1::$3 }
;

init:
  | INIT LEFTBR expr RIGHTBR { loc (), [], $3 } 
  | INIT LEFTPAR lidents RIGHTPAR LEFTBR expr RIGHTBR { loc (), $3, $6 }
;

invariant:
  | INVARIANT LEFTBR expr RIGHTBR { loc (), [], $3 }
  | INVARIANT LEFTPAR lidents RIGHTPAR LEFTBR expr RIGHTBR { loc (), $3, $6 }
;

unsafe:
  | UNSAFE LEFTBR expr RIGHTBR { loc (), [], $3 }
  | UNSAFE LEFTPAR lidents RIGHTPAR LEFTBR expr RIGHTBR { loc (), $3, $6 }
;

transition_name:
  | lident {$1}
  | mident {$1}

transition:
  | TRANSITION transition_name LEFTPAR lidents_thr RIGHTPAR
      fence
      require
      LEFTBR assigns_nondets_updates RIGHTBR
      { let assigns, nondets, upds, writes = $9 in
	  { ptr_name = $2;
            ptr_args = fst $4; 
	    ptr_reqs = fix_rd_expr (snd $4) $7;
	    ptr_assigns = List.map (fix_rd_assign (snd $4)) assigns;
	    ptr_nondets = nondets; 
	    ptr_upds = List.map (fix_rd_upd (snd $4)) upds;
            ptr_loc = loc ();
	    ptr_writes = List.map (fix_rd_write (snd $4)) writes;
	    ptr_fence = $6;
          }
      }
;

assigns_nondets_updates:
  | { [], [], [], [] }
  | assign_nondet_update 
      {  
	match $1 with
	  | Assign (x, y) -> [x, y], [], [], []
	  | Nondet x -> [], [x], [], []
	  | Upd x -> [], [], [x], []
	  | Write (x, y, z, t) -> [], [], [], [x, y, z, t]
      }
  | assign_nondet_update PV assigns_nondets_updates 
      { 
	let assigns, nondets, upds, writes = $3 in
	match $1 with
	  | Assign (x, y) -> (x, y) :: assigns, nondets, upds, writes
	  | Nondet x -> assigns, x :: nondets, upds, writes
	  | Upd x -> assigns, nondets, x :: upds, writes
	  | Write (x, y, z, t) -> assigns, nondets, upds, (x, y, z, t) :: writes
      }
;

assign_nondet_update:
  | assignment { $1 }
  | nondet { $1 }
  | update { $1 }
/*  | write { $1 }*/
;

assignment:
  | mident AFFECT term {
      if is_weak $1 then Write (None, $1, [], PUTerm $3)
      else Assign ($1, PUTerm $3) }
  | mident AFFECT CASE switchs {
      if is_weak $1 then Write (None, $1, [], PUCase $4)
      else Assign ($1, PUCase $4) }
/* Duplicated rules for optional proc (to avoir s/r conflict) */
  | LEFTSQ proc_name RIGHTSQ mident AFFECT term {
      if is_weak $4 then Write (Some $2, $4, [], PUTerm $6)
      else Assign ($4, PUTerm $6) }
  | LEFTSQ proc_name RIGHTSQ mident AFFECT CASE switchs {
      if is_weak $4 then Write (Some $2, $4, [], PUCase $7)
      else Assign ($4, PUCase $7) }
;

nondet:
  | mident AFFECT DOT { Nondet $1 }
  | mident AFFECT QMARK { Nondet $1 }
;

fence:
  | { None }
  | FENCE LEFTPAR proc_name RIGHTPAR { Some $3 }
;

require:
  | { PAtom (AAtom (Atom.True)) }
  | REQUIRE LEFTBR expr RIGHTBR { $3 }
;

update:
  | mident LEFTSQ proc_name_list_plus RIGHTSQ AFFECT CASE switchs {
      if is_weak $1 then Write (None, $1, $3, PUCase $7)
      else begin
        List.iter (fun p ->
          if (Hstring.view p).[0] = '#' then raise Parsing.Parse_error) $3;
        Upd { pup_loc = loc (); pup_arr = $1; pup_arg = $3; pup_swts = $7 }
      end }
  | mident LEFTSQ proc_name_list_plus RIGHTSQ AFFECT term {
      if is_weak $1 then Write (None, $1, $3, PUTerm $6)
      else begin
        let cube, rjs =
          List.fold_left (fun (cube, rjs) i ->
            let j = fresh_var () in
            let c = PAtom (AEq (TVar j, TVar i)) in
            c :: cube, j :: rjs) ([], []) $3 in
        let a = PAnd cube in
        let js = List.rev rjs in
	let sw = [(a, $6); (PAtom (AAtom Atom.True), TTerm (Access($1, js)))] in
	Upd { pup_loc = loc (); pup_arr = $1; pup_arg = js; pup_swts = sw }
      end }
/* Duplicated rules for optional proc (to avoir s/r conflict) */
  | LEFTSQ proc_name RIGHTSQ
        mident LEFTSQ proc_name_list_plus RIGHTSQ AFFECT CASE switchs {
      if is_weak $4 then Write (Some $2, $4, $6, PUCase $10)
      else begin
        List.iter (fun p ->
          if (Hstring.view p).[0] = '#' then raise Parsing.Parse_error) $6;
        Upd { pup_loc = loc (); pup_arr = $4; pup_arg = $6; pup_swts = $10 }
      end }
  | LEFTSQ proc_name RIGHTSQ
        mident LEFTSQ proc_name_list_plus RIGHTSQ AFFECT term {
      if is_weak $4 then Write (Some $2, $4, $6, PUTerm $9)
      else begin
        let cube, rjs =
          List.fold_left (fun (cube, rjs) i ->
            let j = fresh_var () in
            let c = PAtom (AEq (TVar j, TVar i)) in
            c :: cube, j :: rjs) ([], []) $6 in
        let a = PAnd cube in
        let js = List.rev rjs in
	let sw = [(a, $9); (PAtom (AAtom Atom.True), TTerm (Access($4, js)))] in
	Upd { pup_loc = loc (); pup_arr = $4; pup_arg = js; pup_swts = sw }
      end }
;

switchs:
  | BAR UNDERSCORE COLON term { [(PAtom (AAtom (Atom.True)), $4)] }
  | BAR switch { [$2] }
  | BAR switch switchs { $2::$3 }
;

switch:
  | expr COLON term { $1, $3 }
;

/*write:
  | WRITE LEFTPAR proc_name COMMA mident COMMA CASE switchs RIGHTPAR
      { Write (Some $3, $5, [], PUCase $8) }
  | WRITE LEFTPAR proc_name COMMA mident
 	  LEFTSQ proc_name_list_plus RIGHTSQ COMMA CASE switchs RIGHTPAR
      { Write (Some $3, $5, $7, PUCase $11) }
  | WRITE LEFTPAR proc_name COMMA mident COMMA term RIGHTPAR
      { Write (Some $3, $5, [], PUTerm $7) }
  | WRITE LEFTPAR proc_name COMMA mident
 	  LEFTSQ proc_name_list_plus RIGHTSQ COMMA term RIGHTPAR
      { Write (Some $3, $5, $7, PUTerm $10) }*/


constnum:
  | REAL { ConstReal $1 }
  | INT { ConstInt $1 }
;

var_term:
  | mident {
      if is_weak $1 then Read(Hstring.make "", $1, [])
     else if Consts.mem $1 then Const (MConst.add (ConstName $1) 1 MConst.empty)
      else Elem ($1, sort $1) }
  | proc_name { Elem ($1, Var) }
  | LEFTSQ proc_name RIGHTSQ mident {
      if is_weak $4 then Read($2, $4, [])
     else if Consts.mem $4 then Const (MConst.add (ConstName $4) 1 MConst.empty)
      else Elem ($4, sort $4) }
;

top_id_term:
  | var_term { match $1 with
      | Elem (v, Var) -> TVar v
      | _ -> TTerm $1 }
;

array_term:
  | mident LEFTSQ proc_name_list_plus RIGHTSQ {
      if is_weak $1 then Read(Hstring.make "", $1, $3)
      else Access ($1, $3) }
  | LEFTSQ proc_name RIGHTSQ mident LEFTSQ proc_name_list_plus RIGHTSQ {
      if is_weak $4 then Read($2, $4, $6)
      else Access ($4, $6) }
;

/*read_term:
  | READ LEFTPAR proc_name COMMA mident RIGHTPAR
      { Read ($3, $5, []) }
  | READ LEFTPAR proc_name COMMA mident
	 LEFTSQ proc_name_list_plus RIGHTSQ RIGHTPAR
       { Read ($3, $5, $7) }
;*/

var_or_array_term:
  | var_term { $1 }
  | array_term { $1 }
/*  | read_term { $1 }*/
;

arith_term:
  | var_or_array_term PLUS constnum 
      { Arith($1, MConst.add $3 1 MConst.empty) }
  | var_or_array_term MINUS constnum 
      { Arith($1, MConst.add $3 (-1) MConst.empty) }
  | var_or_array_term PLUS mident 
      { Arith($1, MConst.add (ConstName $3) 1 MConst.empty) }
  | var_or_array_term PLUS INT TIMES mident
      { Arith($1, MConst.add (ConstName $5) (Num.int_of_num $3) MConst.empty) }
  | var_or_array_term PLUS mident TIMES INT
      { Arith($1, MConst.add (ConstName $3) (Num.int_of_num $5) MConst.empty) }
  | var_or_array_term MINUS mident 
      { Arith($1, MConst.add (ConstName $3) (-1) MConst.empty) }
  | var_or_array_term MINUS INT TIMES mident 
      { Arith($1, MConst.add (ConstName $5) (- (Num.int_of_num $3)) MConst.empty) }
  | var_or_array_term MINUS mident TIMES INT 
      { Arith($1, MConst.add (ConstName $3) (- (Num.int_of_num $5)) MConst.empty) }
  | INT TIMES mident 
      { Const(MConst.add (ConstName $3) (Num.int_of_num $1) MConst.empty) }
  | MINUS INT TIMES mident 
      { Const(MConst.add (ConstName $4) (- (Num.int_of_num $2)) MConst.empty) }
  | constnum { Const (MConst.add $1 1 MConst.empty) }
;

term:
  | top_id_term { $1 } 
  | array_term { TTerm $1 }
  | arith_term { Smt.set_arith true; TTerm $1 }
/*  | read_term { TTerm $1 }*/
;

lident:
  | LIDENT { Hstring.make $1 }
;

const_proc:
  | CONSTPROC { Hstring.make $1 }
;

proc_name:
  | lident { $1 }
  | const_proc { $1 }
;

proc_name_list_plus:
  | proc_name { [$1] }
  | proc_name COMMA proc_name_list_plus { $1::$3 }
;

mident:
  | MIDENT { Hstring.make $1 }
;

lidents_plus:
  | lident { [$1] }
  | lident lidents_plus { $1::$2 }
;

lidents:
  | { [] }
  | lidents_plus { $1 }
;

lidents_thr_plus:
  | lident { [$1], None }
  | lident lidents_thr_plus { $1::(fst $2), (snd $2) }
  | LEFTSQ lident RIGHTSQ { [$2], Some $2 }
  | LEFTSQ lident RIGHTSQ lidents_plus { $2::$4, Some $2 }
;

lidents_thr:
  | { [], None }
  | lidents_thr_plus { $1 }

lident_list_plus:
  | lident { [$1] }
  | lident COMMA lident_list_plus { $1::$3 }
;


lident_comma_list:
  | { [] }
  | lident_list_plus { $1 }
;

lidents_plus_distinct:
  | lident { [$1] }
  | lident NEQ lidents_plus_distinct { $1 :: $3 }
;


/*
operator:
  | EQ { Eq }
  | NEQ { Neq }
  | LT { Smt.set_arith true; Lt }
  | LE { Smt.set_arith true; Le }
;
*/

literal:
  | TRUE { AAtom Atom.True }
  | FALSE { AAtom Atom.False }
  /* | lident { AVar $1 } RR conflict with proc_name */
  | term EQ term { AEq ($1, $3) }
  | term NEQ term { ANeq ($1, $3) }
  | term LT term { Smt.set_arith true; ALt ($1, $3) }
  | term LE term { Smt.set_arith true; ALe ($1, $3) }
  | term GT term { Smt.set_arith true; ALt ($3, $1) }
  | term GE term { Smt.set_arith true; ALe ($3, $1) }
;

expr:
  | simple_expr { $1 }
  | NOT expr { PNot $2 }
  | expr AND expr { PAnd [$1; $3] }
  | expr OR expr  { POr [$1; $3] }
  | expr IMP expr { PImp ($1, $3) }
  | expr EQUIV expr { PEquiv ($1, $3) }
  | IF expr THEN expr ELSE expr %prec prec_ite { PIte ($2, $4, $6) }
  | FORALL lidents_plus_distinct DOT expr %prec prec_forall { PForall ($2, $4) }
  | EXISTS lidents_plus_distinct DOT expr %prec prec_exists { PExists ($2, $4) }
  | FORALL_OTHER lident DOT expr %prec prec_forall { PForall_other ([$2], $4) }
  | EXISTS_OTHER lident DOT expr %prec prec_exists { PExists_other ([$2], $4) }
;

simple_expr:
  | literal { PAtom $1 }
  | LEFTPAR expr RIGHTPAR { $2 }
  | lident LEFTPAR expr_or_term_comma_list RIGHTPAR { app_fun $1 $3 }
;



expr_or_term_comma_list:
  | { [] }
  | term  { [PT $1] }
  | expr  { [PF $1] }
  | term COMMA expr_or_term_comma_list { PT $1 :: $3 }
  | expr COMMA expr_or_term_comma_list { PF $1 :: $3 }
;
