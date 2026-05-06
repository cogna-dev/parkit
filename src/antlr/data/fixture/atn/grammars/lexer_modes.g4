lexer grammar Modes;

channels { COMMENTS }

OPEN : '/*' -> pushMode(COMMENT_MODE), skip ;
mode COMMENT_MODE;
COMMENT : { can() }? .*? -> channel(COMMENTS) ;