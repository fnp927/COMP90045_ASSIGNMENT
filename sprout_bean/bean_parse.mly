/*
 * The is the file contains our yacc or context free grammar to build the syntax
 * tree in order to check input file meets the syntax of the bean language.
 *
 * Program Description : This program is for the project of COMP90045 
 * at the University of Melbourne,
 * it is a compiler program for the bean language
 *
 * Team Member : 
 * Angus Huang 640386
 * Bingfeng Liu 639187
 * Chesdametrey Seng 748852
 * Chenhao Wei 803931
 *
 * Project Created Date : 18.03.2016
 *
*/


/* ocamlyacc parser for bean */
%{
open Bean_ast
%}

/* Constants */
%token <bool> BOOL_VAL
%token <int> INT_VAL
%token <string> STRING_VAL
/* Keywords */
%token WRITE READ
%token ASSIGN
%token WHILE DO OD
%token IF THEN ELSE FI
%token BOOL INT
%token PROC
%token END
%token VAL
%token REF
%token <string> TYPEDEF
/* Operators */
%token EQ NEQ LT LTE GT GTE
%token PLUS MINUS MUL DIV
%token UMINUS
%token AND OR NOT
%token EQ_COL
/* Punctuation */
%token COLON
%token SEMICOLON
%token DOT
%token COMMA
%token LEFT_PAREN RIGHT_PAREN
%token LEFT_BRACE RIGHT_BRACE
/* Miscellaneous */
%token EOF
%token <string> IDENTIFIER

/* Precedence */
%left OR
%left AND
%nonassoc NOT
%nonassoc EQ NEQ LT LTE GT GTE
%left PLUS MINUS
%left MUL DIV
%right EQ_COL
%nonassoc UMINUS

%type <Bean_ast.program> start_state

%start start_state
%%


/*

The type used for this production rule:

type program = {
  typedefs : (typedefStruct*ident) list;
  funcdefs : (functionDeclaration*typedefStruct list*stmt list) list
}

*/

start_state:
| type_definition procedure_definition {{typedefs = List.rev $1;funcdefs = List.rev $2}}

/*

The data type used for this production rule :

(typedefStruct*ident) list;

This production will check the type declaration for typedef

typedef ? identifier


*/

type_definition:
| type_definition TYPEDEF type_spec IDENTIFIER {($3,$4)::$1}
| {[]}

/*

the typedef data type declaraction will be stored in data structure :

typedefStruct

this production rule is checking the syntax of type declaration

typedef {?} identifier

*/

type_spec:
| primitive_type {$1}
| IDENTIFIER {SingleTypeTerm((IdentType $1))}
| LEFT_BRACE field_definition RIGHT_BRACE {ListTypeTerm( List.rev $2)}

/*

the typedef data type declaraction will be stored in data structure :

typedefStruct

This production rule will return the primitive type of the bean language

*/


primitive_type:
| BOOL {SingleTypeTerm(Bool)}
| INT {SingleTypeTerm(Int)}



field_definition:
| rec_field_definition IDENTIFIER COLON type_spec {SingleTypeTermWithIdent($2,$4)::$1}

/* Commas only present between entries */
rec_field_definition:
| field_definition COMMA {$1}
| {[]}

/* At least one procedure required */
/* (functionDeclaration * typedefStruct  * stmt list) list */
procedure_definition:
| rec_procedure_definition PROC procedure_header variable_definition stmt_list END {($3,List.rev $4,$5)::$1}

rec_procedure_definition:
| procedure_definition {$1}
| {[]}

/*type functionDeclaration = (string*funcDecParamList)*/
/*type funcDecParamList = (valRef*typedefStruct*string) list*/
/*this production rule will check the method declaration, its method name 
  followed by parameters.
*/
procedure_header:
| IDENTIFIER LEFT_PAREN param RIGHT_PAREN {($1,List.rev $3)}

/*type funcDecParamList = (valRef*typedefStruct*string) list*/
/* checking the parameters in right format */
param:
| rec_param param_passing_indicator type_spec IDENTIFIER {($2,$3,$4)::$1}
| {[]}

/* Commas only present between entries */
rec_param:
| param COMMA {$1}
| {[]}

/* Pass by value or reference */
param_passing_indicator:
| VAL {Val}
| REF {Ref}

/*typedefStruct list*/
/* parse the variable declaration in the method body */
variable_definition:
| variable_definition type_spec IDENTIFIER SEMICOLON { SingleTypeTermWithIdent($3,$2)::$1 }
| {[]}

/*procedure , stmt list*/

/* Right recursion to avoid shift/reduce conflicts */
/* checking/parsing the method procedures */
stmt_list:
| atomic_stmt SEMICOLON rec_stmt_list {$1::$3}
| compound_stmt rec_stmt_list {$1::$2}

/* Exists since stmt_list must be non-empty */
rec_stmt_list:
| stmt_list {$1}
| {[]}

/* stmt */
/* check different types of method procedures like assignment, read ,write */
atomic_stmt:
| lvalue EQ_COL rvalue { Assign($1,$3)}
| READ lvalue { Read($2) }
| WRITE expr { Write($2) }
| IDENTIFIER LEFT_PAREN expr_list RIGHT_PAREN { Method($1,$3) }
| IDENTIFIER LEFT_PAREN RIGHT_PAREN { Method($1,[]) }

/* stmt */
/* check compound statements such as 'while' and 'if' */
compound_stmt:
| IF expr THEN stmt_list else_block FI {IfDec($2,$4,$5)}
| WHILE expr DO stmt_list OD {WhileDec($2,$4)}


/* varName.optionalField*/lvalue:
| IDENTIFIER { LId($1) }
| lvalue DOT IDENTIFIER { LField($1,$3) }

/* rvalue*/
rvalue:
| expr { Rexpr($1) }
| LEFT_BRACE field_init RIGHT_BRACE { Rstmts(List.rev $2) }
| LEFT_BRACE RIGHT_BRACE { Rempty }

/* rvalue list */
field_init:
| rec_field_init IDENTIFIER EQ rvalue {Rassign($2,$4)::$1}

rec_field_init:
| field_init COMMA {$1}
| {[]}

/* check expression */
expr:
| lvalue { Elval($1) }
| const { $1 }
| LEFT_PAREN expr RIGHT_PAREN { Ebracket($2) }
| expr PLUS expr { Ebinop($1,Op_add,$3) }
| expr MINUS expr { Ebinop($1,Op_sub,$3) }
| expr MUL expr { Ebinop($1,Op_mul,$3) }
| expr DIV expr { Ebinop($1,Op_div,$3) }
| expr EQ expr { Ebinop($1,Op_eq,$3) }
| expr NEQ expr { Ebinop($1,Op_neq,$3) }
| expr LT expr { Ebinop($1,Op_lt,$3) }
| expr GT expr { Ebinop($1,Op_gt,$3) }
| expr LTE expr { Ebinop($1,Op_lte,$3) }
| expr GTE expr { Ebinop($1,Op_gte,$3) }
| expr AND expr { Ebinop($1,Op_and,$3) }
| expr OR expr { Ebinop($1,Op_or,$3) }
| NOT expr { Eunop(Op_not,$2) }
| MINUS expr %prec UMINUS { Eunop(Op_minus,$2) } /* Precedence for unary minus */

/* Right recursion to avoid shift/reduce conflicts */
expr_list:
| expr rec_expr_list { $1::$2 }

/* Commas only present between entries */
rec_expr_list:
| COMMA expr_list { $2 }
| {[]}

/* check statments under else */
else_block:
| ELSE stmt_list {$2}
| {[]}

/* check literals*/
const:
| BOOL_VAL { Ebool($1) }
| INT_VAL { Eint($1) }
| STRING_VAL { Eident($1) }
