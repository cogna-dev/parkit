///|
fn expect_analyzed(source : String) -> SemanticSummary {
  let grammar = expect_parsed(source)
  analyze_grammar(grammar)
}

///|
test "semantic analysis accepts Hello grammar" {
  let summary = expect_analyzed(
    "grammar Hello;\n\nr : 'hello' ID ;\nID : [a-z]+ ;\nWS : [ \\r\\t\\n]+ -> skip ;\n",
  )
  assert_eq(summary.diagnostics.length(), 0)
  assert_eq(summary.parser_rule_names.length(), 1)
  assert_eq(summary.lexer_rule_names.length(), 2)
  match summary.start_rule_name {
    Some(name) => assert_eq(name, "r")
    None => abort("expected start rule name")
  }
  match summary.grammar_fingerprint {
    Some(fingerprint) => assert_eq(fingerprint.length() > 0, true)
    None => abort("expected grammar fingerprint")
  }
  match summary.semantic_model {
    Some(model) => {
      assert_eq(model.rules.length(), 3)
      assert_eq(model.tokens.length(), 3)
      assert_eq(model.slots.length() >= 3, true)
    }
    None => abort("expected semantic model")
  }
}

///|
test "semantic analysis rejects lexer rules in parser grammar" {
  let summary = expect_analyzed(
    "parser grammar Broken;\n\nstart : ID ;\nID : 'a' ;\n",
  )
  assert_eq(summary.diagnostics.length(), 1)
  assert_eq(
    summary.diagnostics[0].message,
    "lexer rule `ID` is not allowed in parser grammar",
  )
}

///|
test "semantic analysis reports undefined refs and alt label conflicts" {
  let summary = expect_analyzed(
    "grammar Bad;\n\nstat : missing # Stat ;\nID : [a-z]+ ;\n",
  )
  assert_eq(summary.diagnostics.length(), 2)
  assert_eq(
    summary.diagnostics[0].message,
    "alternative label `Stat` conflicts with rule `stat`",
  )
  assert_eq(
    summary.diagnostics[1].message,
    "undefined parser rule reference `missing`",
  )
}

///|
test "semantic analysis allows alt labels that only match lexer token names" {
  let summary = expect_analyzed(
    "grammar Expr;\n\nexpr : INT # int | ID # id ;\nID : [a-z]+ ;\nINT : [0-9]+ ;\nWS : [ \\r\\t\\n]+ -> skip ;\n",
  )
  assert_eq(summary.diagnostics.length(), 0)
}

///|
test "semantic analysis rejects parser rule refs in lexer rules" {
  let summary = expect_analyzed(
    "lexer grammar BrokenLexer;\n\nA : b ;\nb : 'b' ;\n",
  )
  assert_eq(summary.diagnostics.length(), 2)
  assert_eq(
    summary.diagnostics[0].message,
    "parser rule `b` is not allowed in lexer grammar",
  )
  assert_eq(
    summary.diagnostics[1].message,
    "parser rule reference `b` is not allowed in lexer rule `A`",
  )
}

///|
test "semantic analysis reports duplicate public symbols" {
  let summary = expect_analyzed(
    "lexer grammar Dup;\n\ntokens { ID, ID }\nchannels { COMMENTS, COMMENTS }\nmode COMMENT;\nmode COMMENT;\nA : 'a' ;\nA : 'b' ;\n",
  )
  assert_eq(summary.diagnostics.length() >= 4, true)
  assert_eq(summary.semantic_model is None, true)
}
