lexer grammar LexerCommandModes;

channels { COMMENTS }

OPEN : '/*' -> pushMode(COMMENT_MODE), skip ;
ID : [a-z]+ ;
WS : [ \r\t\n]+ -> skip ;

mode COMMENT_MODE;
COMMENT : { can() }? .*? '*/' -> channel(COMMENTS), popMode ;