lexer grammar FragmentRefs;

WORD : Letter+ ;
WS : Whitespace+ -> skip ;

fragment Letter : [a-z] ;
fragment Whitespace : ' ' ;