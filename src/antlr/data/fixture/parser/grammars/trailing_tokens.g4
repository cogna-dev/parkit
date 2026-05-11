grammar TrailingTokens;

s : ID ID ;

ID : [a-z]+ ;
WS : [ \r\t\n]+ -> skip ;