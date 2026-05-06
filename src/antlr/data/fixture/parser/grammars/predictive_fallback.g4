grammar PredictiveFallback;

s : stmt EOF ;

stmt
  : ID '=' ID # Assign
  | ID '(' ID ')' # Call
  ;

ID : [a-z]+ ;
WS : [ \r\t\n]+ -> skip ;