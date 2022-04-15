type bop = Add | Sub | Eq | Neq | Less | And | Or
          | Mult | Div | Great | Leq | Geq | Mod


type uop = Not

type builtin_type = 
  | NoneType
  | StrType
  | IntType
  | BoolType
  | FloatType
  | ArrayType of builtin_type

type expr =
  | StrLit of string
  | IntLit of int
  | FloatLit of float
  | BoolLit of bool
  | NoneLit
  | Id of string
  | Assign of string * expr
  | FuncCall of string * expr list
  | Binop of expr * bop * expr
  | Unop of uop * expr
  | TypeCast of builtin_type * expr
  | Noassign of builtin_type

type stmt =
  | Expr of expr
  | Block of stmt list
  | If of expr * stmt * stmt
  | While of expr * stmt
  | For of expr * expr * expr * stmt
  | Return of expr
  | Local of builtin_type * string * expr
  
type bind = builtin_type * string

type func_def = {
  rtyp: builtin_type;
  fname: string;
  formals: bind list;
  locals: bind list;
  body: stmt list;
}

(* ----- Entry ----- *)
type program = func_def list