grammar ParserPredicate;

s : item EOF ;

item
  : { allow() }? ID # Allowed
  | ID ID # Pair
  ;

ID : [a-z]+ ;
WS : [ \r\t\n]+ -> skip ;