%{
open Ast
%}

/* arithmetic */
%token PLUS MINUS TIMES DIVIDE MOD

/* assignment */
%token ASSIGN PLUSEQ MINUSEQ TIMESEQ DIVEQ MODEQ

/* relational */
%token EQ NEQ GTEQ LTEQ GT LT AND OR NOT QUESTION

/* keywords */
%token FUNC IF ELSE ELIF FOR WHILE INFINITE_LOOP RETURN BREAK
%token CONTINUE TRY CATCH RAISE LINK USE IN STEP AS 

/* type */
%token T_NONE T_STR T_INT T_BOOL T_FLOAT

/* delimiters */
%token SEMI LPAREN RPAREN LBRACE RBRACE COLON COMMA LBRACKET RBRACKET DOT
%token EOF

/* split id into two, nothing changes outside of parser file */

%token <string> ID_FUNC /* function names */
%token <string> ID_VAR /* variable access or assign */
%token <string> ID_VAR_DECL /* variable decl */
%token <string> LIT_STR
%token <int> LIT_INT
%token <float> LIT_FLOAT
%token <bool> LIT_BOOL


/* precedence following C standard*/
%left COMMA
%left SEMI 
%right ASSIGN PLUSEQ MINUSEQ TIMESEQ DIVEQ MODEQ
%left OR
%left AND
%left EQ NEQ
%left LT GT LTEQ GTEQ
%left PLUS MINUS
%left TIMES DIVIDE MOD
%right NOT


%start program
%type <Ast.program> program

%%


program:
  decls EOF { $1 }

decls:
   /* nothing */ { ([], [])               }
 | vdecl SEMI decls { (($1 :: fst $3), snd $3) }
 | fdecl decls { (fst $2, ($1 :: snd $2)) }

vdecl_list:
  /*nothing*/ { [] }
  | vdecl SEMI vdecl_list  {  $1 :: $3 }
  | vdecl_assign SEMI vdecl_list {$1 :: $3}

/* @@x: string; */
vdecl:
  | ID_VAR_DECL COLON typ {($3, $1)}

vdecl_assign:
  vdecl ASSIGN expr { fst ((fst $1, snd $1), Assign(snd $1, $3))}

typ:
  | T_NONE { NoneType }
  | T_STR { StrType }
  | T_INT { IntType }
  | T_BOOL { BoolType }
  | T_FLOAT { FloatType }


/* function declaration */
fdecl:
  /* func with args */ 
  | FUNC ID_FUNC LPAREN formals_opt RPAREN COLON typ LBRACE vdecl_list stmt_list RBRACE
  {
    { 
      rtyp = $7;
      fname = $2;
      formals = $4;
      locals = $9;
      body = $10;
    }
  }

/* formals_opt */
formals_opt:
  /*nothing*/ { [] }
| formals_list { $1 }

formals_list:
  vdecl { [$1] }
  | vdecl COMMA formals_list { $1::$3 }

stmt_list:
  /* nothing */ { [] }
  | stmt stmt_list  { $1::$2 }


stmt:
  | expr SEMI                               { Expr $1      }
  | logic_expr                              { Expr $1 }
  /*| LBRACE stmt_list RBRACE                 { Block $2 } */
  /*| IF LPAREN expr RPAREN stmt ELSE stmt    { If($3, $5, $7) }*/
  | if_stmt                                 { $1 }
  | block                                   { $1 }
  | loop                                    { $1 }
  | RETURN expr SEMI                        { Return $2      }

logic_expr: /* within control flow, we dont want SEMI involved in our exprs */
  | expr { $1}

loop:
  | WHILE expr stmt           { While ($2, $3)  }
  | INFINITE_LOOP stmt        { While (BoolLit(true), $2)  }
  /*| FOR LPAREN expr SEMI expr SEMI expr RPAREN stmt
                                            { For($3, $5, $7, $9)   } */
  /*| FOR ID_VAR IN LIT_INT DOT DOT DOT end_condition LIT_INT increment

end_condition:
  | 

increment: */
  /* nothing */ 

/*
for counter in starting_num ... <ending condition>ending_num step step_number
 condition    
    < > <= >=
 step_number defaults to 1 if there is nothing present
*/

block: 
  | LBRACE stmt_list RBRACE                 { Block $2 }

if_stmt:
  | expr QUESTION stmt COLON stmt            { If($1, $3, $5) } /* (1 > 2) ? print("true") : print("false") */
  | IF LPAREN expr RPAREN block else_stmt    { If($3, $5, $6) } /* if else? */
  /*| IF LPAREN expr RPAREN stmt              { If($3, $5, No_op)     } */ /* if */

else_stmt:
  /* no else block */ { No_op }
  | ELSE stmt { $2 }

/* IDK how to do elif yet, may just wait
elif_stmt:
  | ELIF LPAREN expr RPAREN block { ... }

if_stmt:
    | 'if' named_expression ':' block elif_stmt 
    | 'if' named_expression ':' block [else_block] 
elif_stmt:
    | 'elif' named_expression ':' block elif_stmt 
    | 'elif' named_expression ':' block [else_block] 
*/


expr:
  /* literal */
  | LIT_STR { StrLit($1) }
  | LIT_INT { IntLit($1) }
  | LIT_BOOL { BoolLit($1) }
  | LIT_FLOAT { FloatLit($1) }

  /* variable */
  | ID_VAR { Id($1) }

  /* arithmetic */
  | expr PLUS   expr { Binop($1, Add,   $3)   }
  | expr MINUS  expr { Binop($1, Sub,   $3)   }
  | expr TIMES  expr { Binop($1, Mult,  $3)   }
  | expr DIVIDE expr { Binop($1, Div,   $3)   }
  | expr MOD    expr { Binop($1, Div,   $3)   }

  /* logical binary ops */
  | expr  EQ      expr { Binop($1, Eq, $3)   }
  | expr  NEQ     expr { Binop($1, Neq,   $3)   }
  | expr  LT      expr { Binop($1, Less,  $3)   }
  | expr  GT      expr { Binop($1, Great, $3) }
  | expr  LTEQ    expr { Binop($1, Leq,   $3)   }
  | expr  GTEQ    expr { Binop($1, Geq,   $3)   }

  /* logical ops */
  | expr  AND    expr { Binop($1, And,   $3)   }
  | expr  OR     expr { Binop($1, Or,    $3)   }
  | NOT   expr        { Unop(Not, $2) }

  /* assignment */
  | ID_VAR ASSIGN expr { Assign($1, $3) }

  /* remove clarifying parens */
  | LPAREN expr RPAREN { $2 } /* (expr) -> expr. get rid of parens */

  /* function call */
  | ID_FUNC LPAREN args_opt RPAREN { FuncCall($1, $3) }

  

/* args_opt*/
args_opt:
  /*nothing*/ { [] }
  | args { $1 }

args:
  expr  { [$1] }
  | expr COMMA args { $1::$3 }