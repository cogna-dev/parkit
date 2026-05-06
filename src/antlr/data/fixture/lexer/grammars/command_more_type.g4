lexer grammar CommandMoreType;

channels { DOCS }

OPEN : '<' -> more, pushMode(TAG) ;
TEXT : [a-z]+ ;
WS : [ \r\t\n]+ -> skip ;

mode TAG;
NAME : [a-z]+ '>' -> type(TEXT), channel(DOCS), popMode ;