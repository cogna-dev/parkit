grammar CardinalityMix;

root
  : maybe=MAYBE? many+=ITEM* some+=REQ+
  ;

MAYBE : 'm' ;
ITEM : 'i' ;
REQ : 'r' ;
WS : [ \r\t\n]+ -> skip ;