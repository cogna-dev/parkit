grammar Expr;

expr
  : expr '+' expr # Add
  | INT # Atom
  ;

INT : [0-9]+ ;
WS : [ \r\t\n]+ -> skip ;