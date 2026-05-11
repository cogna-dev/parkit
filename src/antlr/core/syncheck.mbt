///|
fn expect_parsed(source : String) -> GrammarSpec {
  let outcome = parse_grammar(source)
  if outcome.diagnostics.length() != 0 {
    abort(outcome.diagnostics[0].message)
  }
  match outcome.grammar {
    Some(grammar) => grammar
    None => abort("expected parse success")
  }
}

///|
test "parse real Hello.g4 subset" {
  let grammar = expect_parsed(
    "grammar Hello;\n\nimport HelloBase;\n\nr  : 'hello' ID ;\nID : [a-z]+ ;\nWS : [ \\r\\t\\n]+ -> skip ;\n",
  )
  assert_eq(grammar.name, "Hello")
  assert_eq(grammar.imports.length(), 1)
  assert_eq(grammar.imports[0], "HelloBase")
  assert_eq(grammar.rules.length(), 3)
  match grammar.rules[0].kind {
    ParserRule => ()
    _ => abort("expected parser rule")
  }
  match grammar.rules[0].alternatives[0].elements[0].kind {
    StringLiteralElement(text) => assert_eq(text, "'hello'")
    _ => abort("expected string literal")
  }
  match grammar.rules[2].alternatives[0].elements[0].kind {
    CharSetElement(text) => assert_eq(text, "[ \\r\\t\\n]")
    _ => abort("expected charset")
  }
  match grammar.rules[2].alternatives[0].elements[0].suffix {
    Some(suffix) =>
      match suffix.kind {
        OneOrMoreSuffix => assert_eq(suffix.greedy, true)
        _ => abort("expected one-or-more suffix")
      }
    None => abort("expected suffix")
  }
  assert_eq(grammar.rules[2].alternatives[0].commands.length(), 1)
  assert_eq(grammar.rules[2].alternatives[0].commands[0].name, "skip")
}

///|
test "parse parser grammar with labels and groups" {
  let grammar = expect_parsed(
    "parser grammar Expr;\n\nexpr\n  : <assoc=right> expr '?' expr ':' expr # Conditional\n  | expr '*' expr # Mul\n  | expr '+' expr # Add\n  | atom # Atom\n  ;\n\natom\n  : ID ('(' expr (',' expr)* ')')?\n  ;\n",
  )
  assert_eq(grammar.rules.length(), 2)
  assert_eq(grammar.rules[0].alternatives[0].options.length(), 1)
  assert_eq(grammar.rules[0].alternatives[0].options[0].name, "assoc")
  assert_eq(grammar.rules[0].alternatives[0].options[0].value, "right")
  match grammar.rules[0].alternatives[0].label {
    Some(label) => assert_eq(label, "Conditional")
    None => abort("expected alternative label")
  }
  assert_eq(grammar.rules[1].alternatives[0].elements.length(), 2)
  match grammar.rules[1].alternatives[0].elements[1].kind {
    GroupElement(alternatives) => assert_eq(alternatives.length(), 1)
    _ => abort("expected group element")
  }
  match grammar.rules[1].alternatives[0].elements[1].suffix {
    Some(suffix) =>
      match suffix.kind {
        OptionalSuffix => assert_eq(suffix.greedy, true)
        _ => abort("expected optional suffix")
      }
    None => abort("expected optional suffix")
  }
}

///|
test "parse lexer grammar with modes and nongreedy wildcard" {
  let grammar = expect_parsed(
    "lexer grammar Modes;\n\nchannels { COMMENTS }\n\n@members { int depth = 0; }\n\nOPEN : '/*' -> pushMode(COMMENT_MODE) ;\nmode COMMENT_MODE;\nCOMMENT : .*? -> channel(COMMENTS), skip ;\nCLOSE : '*/' -> popMode ;\n",
  )
  assert_eq(grammar.channel_names.length(), 1)
  assert_eq(grammar.channel_names[0], "COMMENTS")
  assert_eq(grammar.named_actions.length(), 1)
  assert_eq(grammar.named_actions[0].name, "members")
  assert_eq(grammar.modes.length(), 1)
  assert_eq(grammar.modes[0], "COMMENT_MODE")
  match grammar.rules[1].mode {
    Some(mode_name) => assert_eq(mode_name, "COMMENT_MODE")
    None => abort("expected mode on lexer rule")
  }
  match grammar.rules[1].alternatives[0].elements[0].kind {
    WildcardElement => ()
    _ => abort("expected wildcard element")
  }
  match grammar.rules[1].alternatives[0].elements[0].suffix {
    Some(suffix) =>
      match suffix.kind {
        ZeroOrMoreSuffix => assert_eq(suffix.greedy, false)
        _ => abort("expected zero-or-more suffix")
      }
    None => abort("expected suffix on wildcard")
  }
  assert_eq(grammar.rules[1].alternatives[0].commands.length(), 2)
  assert_eq(grammar.rules[1].alternatives[0].commands[0].name, "channel")
  match grammar.rules[1].alternatives[0].commands[0].args {
    Some(args) => assert_eq(args, "(COMMENTS)")
    None => abort("expected command args")
  }
  assert_eq(grammar.rules[1].alternatives[0].commands[1].name, "skip")
}

///|
test "parse lexer grammar fragments from upstream style fixtures" {
  let grammar = expect_parsed(
    "lexer grammar TestBaseLexer;\n\ntokens  { Name }\n\nComment : '<!--' .*? '-->' ;\nfragment Whitespace : ' ' | '\\n' | '\\t' | '\\r' ;\nfragment Digit : [0-9] ;\nWS : Whitespace+ -> skip ;\n",
  )
  assert_eq(grammar.rules.length(), 4)
  assert_eq(grammar.rules[1].is_fragment, true)
  assert_eq(grammar.rules[2].is_fragment, true)
  assert_eq(grammar.rules[3].is_fragment, false)
  match grammar.rules[3].alternatives[0].elements[0].kind {
    TokenReferenceElement(name) => assert_eq(name, "Whitespace")
    _ => abort("expected lexer fragment reference to remain token-like")
  }
}

///|
test "parse lexer literal ranges from upstream style fixtures" {
  let grammar = expect_parsed(
    "lexer grammar Calc;\n\nID : 'a' .. 'z'+ ;\nINT : '0' .. '9'+ ;\nWS : ' ' + ;\n",
  )
  match grammar.rules[0].alternatives[0].elements[0].kind {
    RangeElement(text) => assert_eq(text, "'a' .. 'z'")
    _ => abort("expected range element")
  }
  match grammar.rules[0].alternatives[0].elements[0].suffix {
    Some(suffix) =>
      match suffix.kind {
        OneOrMoreSuffix => ()
        _ => abort("expected one-or-more suffix on range")
      }
    None => abort("expected suffix on range")
  }
}

///|
test "parse parser rule catch and finally trailers" {
  let grammar = expect_parsed(
    "parser grammar Demo;\n\nrule returns [int value] : ID ;\ncatch [RecognitionException e] { recover(); }\nfinally { cleanup(); }\n",
  )
  assert_eq(grammar.rules.length(), 1)
  assert_eq(grammar.rules[0].trailers.length(), 2)
  match grammar.rules[0].trailers[0].kind {
    CatchRuleTrailer => ()
    _ => abort("expected catch trailer")
  }
  match grammar.rules[0].trailers[0].header {
    Some(header) => assert_eq(header, "[RecognitionException e]")
    None => abort("expected catch header")
  }
  match grammar.rules[0].trailers[1].kind {
    FinallyRuleTrailer => ()
    _ => abort("expected finally trailer")
  }
}

///|
test "parse semantic predicate with fail suffix" {
  let grammar = expect_parsed(
    "parser grammar Demo;\n\nrule : ID { check($ID) } ? <fail = { \"broken\" }> ;\n",
  )
  assert_eq(grammar.rules.length(), 1)
  assert_eq(grammar.rules[0].alternatives.length(), 1)
  assert_eq(grammar.rules[0].alternatives[0].elements.length(), 2)
  match grammar.rules[0].alternatives[0].elements[1].kind {
    PredicateElement(body, suffix) => {
      assert_eq(body, "{ check($ID) }")
      match suffix {
        Some(raw_suffix) => assert_eq(raw_suffix, "<fail = { \"broken\" }>")
        None => abort("expected predicate suffix")
      }
    }
    _ => abort("expected predicate element")
  }
}
