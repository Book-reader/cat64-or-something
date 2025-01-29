grammar ExprParser;
//options { tokenVocab=ExprLexer; }

program
  : statement+ EOF ;

statement
  : LABEL_DECL ( EOS SEPERATOR* | SEPERATOR+ ) instruction EOS+
  | SEPERATOR* instruction EOS+ ;

instruction
  : INSTRUCTION ( SEPERATOR+ arg ( SEPERATOR* ARG_SEP SEPERATOR* arg )? )? SEPERATOR*
  ;

arg
 : expr
 | DEREF_START SEPERATOR* expr SEPERATOR* DEREF_END
 ;

expr
 : expr SEPERATOR* OPERATION SEPERATOR* expr
 | NUMBER
 | CHAR
 | REGISTER
 | LABEL
 ;

INSTRUCTION
 : STRING PERIOD NUMBER?
 ;
 
LABEL: STRING ;
 
OPERATION: '+' | '-' | '*' | '/' ;

DEREF_START: '[' ;

DEREF_END: ']' ;

EOS: ';' | '\n' ;

STRING: [A-Za-z_]+ ;

NUMBER : [0-9]+ | '0x' [0-9a-fA-F]+ ;

CHAR: '\'' [A-Za-z0-9] '\'' ;

REGISTER: 'r' [0-9]* | 'rdi' | 'rsi' ;

LABEL_DECL: LABEL ':' ;

SEPERATOR: ' ' ;

ARG_SEP : ',' ;

PERIOD: '.' ;
