(* Semantic checking for the Viz compiler *)

open Ast
open Sast

module StringMap = Map.Make(String)

let builtin_funcs = [
  {name = "print"; typ = NoneType; params = [(StrType, "x")]; body = []};
]

(* Return a function from our symbol table *)
let find_func ctxt s = 
  try StringMap.find s ctxt
  with Not_found -> raise (Failure ("unrecognized function " ^ s))

(* Semantic checking of the AST. Returns an SAST if successful,
  throws an exception if something is wrong.

    (* we should enforce this *)
(* let _ = find_func "main" in (* Ensure "main" is defined *) *)

(* we also need like a check binds funciton to ensure no duplicate definitions
look at microC *)

  Check each global variable, then check each function *)
let rec check_program (program : stmt list) =
  let check_stmt (ctxt: func_decl StringMap.t) func = 
    (* Build local symbol table of variables for this function *)
    let symbols = List.fold_left (fun m (ty, name) -> StringMap.add name ty m)
      StringMap.empty []
    in

    (* Return a variable from our local symbol table *)
    let check_id (symbols: builtin_type StringMap.t ) id =
      try StringMap.find id symbols
      with Not_found -> raise (Failure ("undeclared identifier " ^ id))
    in

    (* Return a semantically-checked expression (typ, expr) *)
    let rec check_expr (symbols: builtin_type StringMap.t) expr =
      let check_assign ltyp rtyp err =
        if ltyp = rtyp then ltyp else raise (Failure err)
      in

      let check_call (name, args) =
        let fd = find_func ctxt name in
        let params_length = List.length fd.params in
        if List.length args != params_length then
          raise (Failure ("expecting " ^ string_of_int params_length ^ 
                          " arguments in " ^ name))
        else let check_arg (ft, _) arg =
          let (et, e') = check_expr symbols arg in
          let err = "illegal argument found " ^ fmt_typ et ^
          " expected " ^ fmt_typ ft ^ " in " ^ fmt_expr arg 
        in (check_assign ft et err, e') in

        let sargs = List.map2 check_arg fd.params args
        in (fd.typ, SFuncCall(name, sargs))
      
      in match expr with
        | IntLit x -> (IntType, SIntLit x)
        | FloatLit x -> (FloatType, SFloatLit x)
        | StrLit x -> (StrType, SStrLit x)
        | Assign(v, e) as ex ->
          let lt = check_id symbols v
          and (rt, e') = check_expr symbols e in
          let err = "illegal assignment " ^ fmt_typ lt ^ " = " ^
              fmt_typ rt ^ " in " ^ fmt_expr ex
          in
          (check_assign lt rt err, SAssign(v, (rt, e')))
        | BoolLit x -> (BoolType, SBoolLit x)
        | Id x -> (check_id symbols x, SId x)
        | FuncCall (name, args) -> check_call (name, args)
        | Unop(uo, r) as ex ->
          let (rtype, r') = check_expr symbols r in
          let final_type = 
            (* if we add other unary operands, we may need to be more clever 
            with type support. Right now, we are supporting Not, so this is ok.  
            *)
            if rtype != BoolType then
              raise (Failure ("incompatible types for unary operator " ^
              fmt_uop uo ^ " " ^ fmt_typ rtype ^ " in " ^ fmt_expr ex))
            else
              (fun my_uop -> match my_uop with 
              | Not -> BoolType
              ) uo
            in (final_type, SUnop(uo, (rtype, r')))
        | Binop(l, bo, r) as ex-> 
          let (ltype, l') = check_expr symbols l in
          let (rtype, r') = check_expr symbols r in
          (* we can only do binop on operands of same type *)
          let compatible_types = (ltype = rtype) in
          (* throw error, or return final_type for supported binops *)
          let final_type = 
            if compatible_types = false then
              raise (Failure ("incompatible types for binary operator " ^
                       fmt_typ ltype ^ " " ^ fmt_op bo ^ " " ^
                       fmt_typ rtype ^ " in " ^ fmt_expr ex))
            
            else           
              (fun my_op -> match my_op with
              | (Add | Sub | Mult | Div | Mod) when ltype = IntType && rtype = IntType -> IntType
              | (Add | Sub | Mult | Div | Mod) when ltype = FloatType && rtype = FloatType -> FloatType
              | (Eq | Neq) -> BoolType
              | (Leq | Geq | Less | Great) when (ltype = IntType && rtype = IntType ||
                                                 ltype = FloatType && rtype = FloatType) -> BoolType
              | (And | Or) when (ltype = BoolType && rtype = BoolType) -> BoolType
              | _ -> raise (Failure ("No operator (" ^ fmt_op bo ^ ") " ^ "to handle type (" ^
                            fmt_typ ltype ^ ", " ^ fmt_typ rtype))
              ) bo
          in (final_type, SBinop((ltype, l'), bo, (rtype, r')))

    in
    
    let check_bool_expr e =
      let (t, e') = check_expr symbols e in
      match t with
      | BoolType -> (t, e')
      |  _ -> raise (Failure ("expected Boolean expression in " ^ fmt_expr e))
    in
    
    let check_function f = 
      {
        styp = f.typ;
        sname = f.name;
        sparams = f.params;
        sbody = check_program f.body;
      }
    in   
    let rec check_stmt_list = function
        [] -> []
      | Block sl :: sl'  -> check_stmt_list (sl @ sl') (* Flatten blocks *)
      | s :: sl -> check_stmt s :: check_stmt_list sl
    (* Return a semantically-checked statement i.e. containing sexprs *)
    and check_stmt = function
    (* match stmt with *)
      | Expr e -> SExpr (check_expr symbols e)
      | VarDecl (b, e) -> (match e with
          | None -> SVarDecl(b, None)
          | Some(e) -> SVarDecl(b, Some(check_expr symbols e)))
      | FuncDecl fd -> SFuncDecl (check_function fd)
      | Block sl -> SBlock (check_stmt_list sl)
      | If(e, st1, st2) ->
        SIf(check_bool_expr e, check_stmt st1, check_stmt st2)
      (*| Return e ->
        let (t, e') = check_expr symbols e in
        (* let func_type =  *)
        if t = func.styp then SReturn (t, e')
        else raise (
          Failure ("return gives " ^ fmt_typ t ^ " expected " ^
          fmt_typ f.styp ^ " in " ^ fmt_expr e)
          ) *)
      | _ -> raise (Failure "unimplemented")
      
      (*in 
      {
        styp = func.typ;
        sname = func.name;
        sparams = func.params;
        sbody = check_stmt_list func.body;
      }*)

  in
  let ctxt = 
    let add_func map fd = StringMap.add fd.name fd map in
    List.fold_left add_func StringMap.empty builtin_funcs
  in
  List.map (fun stmt -> check_stmt ctxt stmt) program