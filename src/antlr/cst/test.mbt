///|
fn expect_runtime_atn(source : String) -> @antlr.GrammarAtn {
  let report = @antlr.run_frontend_pipeline(source)
  if report.has_errors() {
    let diagnostics = report.all_diagnostics()
    if diagnostics.length() == 0 {
      abort("expected frontend success for cst fixture")
    }
    abort(diagnostics[0].message)
  }
  match report.grammar_atn {
    Some(atn) => atn
    None => abort("expected runtime fixture ATN")
  }
}

///|
fn cst_lexer_hooks_for_fixture(
  fixture : @antlr_fixture.CstGoldenSnapshotFixture,
) -> @antlr_runtime.LexerHostHooks {
  let mut hooks = @antlr_runtime.LexerHostHooks::empty()
  for predicate in fixture.lexer_true_predicates {
    hooks = hooks.with_predicate(predicate, true)
  }
  for binding in fixture.lexer_action_labels {
    hooks = hooks.with_action(binding.text, binding.label)
  }
  hooks
}

///|
fn cst_parser_hooks_for_fixture(
  fixture : @antlr_fixture.CstGoldenSnapshotFixture,
) -> @antlr_runtime.ParserHostHooks {
  let mut hooks = @antlr_runtime.ParserHostHooks::empty()
  for predicate in fixture.parser_true_predicates {
    hooks = hooks.with_predicate(predicate, true)
  }
  for binding in fixture.parser_action_labels {
    hooks = hooks.with_action(binding.text, binding.label)
  }
  hooks
}

///|
fn any_cst_fixture_by_id(
  fixture_id : String,
) -> @antlr_fixture.CstGoldenSnapshotFixture {
  for fixture in @antlr_fixture.representative_cst_snapshots() {
    if fixture.id == fixture_id {
      return fixture
    }
  }
  for fixture in @antlr_fixture.upstream_cst_snapshots() {
    if fixture.id == fixture_id {
      return fixture
    }
  }
  abort("expected cst fixture `" + fixture_id + "`")
}

///|
fn cst_document_for_fixture(
  fixture : @antlr_fixture.CstGoldenSnapshotFixture,
  parser_hooks : @antlr_runtime.ParserHostHooks,
) -> CstDocument {
  let atn = expect_runtime_atn(fixture.source)
  let lexer_result = @antlr_runtime.lex_with_atn(
    atn,
    fixture.input,
    cst_lexer_hooks_for_fixture(fixture),
  )
  if lexer_result.diagnostics.length() != 0 {
    abort(lexer_result.diagnostics[0].message)
  }
  let parsed = @antlr_runtime.parse_with_atn(
    atn,
    lexer_result.tokens,
    parser_hooks,
  )
  match build_cst_document(atn, parsed) {
    Ok(document) => document
    Err(error) => abort(error)
  }
}

///|
fn assert_cst_snapshot(fixture_id : String) -> Unit {
  let fixture = any_cst_fixture_by_id(fixture_id)
  let actual = serialize_cst_document(
    cst_document_for_fixture(fixture, cst_parser_hooks_for_fixture(fixture)),
  )
  if actual != fixture.expected_serialized_document {
    println(actual)
    abort("cst golden snapshot mismatch for `" + fixture.id + "`")
  }
}

///|
fn first_token_id_by_lexeme(
  document : CstDocument,
  lexeme : String,
) -> CstTokenId {
  for record in document.tokens {
    if record.lexeme == lexeme {
      return record.id
    }
  }
  abort("expected token lexeme `" + lexeme + "`")
}

///|
test "cst snapshot representative hello-basic-local" {
  assert_cst_snapshot("hello-basic-local")
}

///|
test "cst snapshot representative expr-left-recursive" {
  assert_cst_snapshot("expr-left-recursive")
}

///|
test "cst snapshot representative parser-predicate" {
  assert_cst_snapshot("parser-predicate")
}

///|
test "cst snapshot representative trailing-tokens" {
  assert_cst_snapshot("trailing-tokens")
}

///|
test "cst snapshot upstream visitor-basic" {
  assert_cst_snapshot("visitor-basic")
}

///|
test "cst snapshot upstream visitor-calc-hidden" {
  assert_cst_snapshot("visitor-calc-hidden")
}

///|
test "cst snapshot upstream python-expr" {
  assert_cst_snapshot("python-expr")
}

///|
test "cst snapshot upstream hello-basic-upstream" {
  assert_cst_snapshot("hello-basic-upstream")
}

///|
test "cst query projects left recursion onto original slots" {
  let fixture = any_cst_fixture_by_id("expr-left-recursive")
  let document = cst_document_for_fixture(
    fixture,
    cst_parser_hooks_for_fixture(fixture),
  )
  match node(document, document.root) {
    Rule(root_rule) => {
      assert_eq(root_rule.alternative is Some(_), true)
      assert_eq(children(document, document.root).length(), 3)
      assert_eq(children_by_slot(document, document.root, 0).length(), 1)
      assert_eq(children_by_slot(document, document.root, 1).length(), 1)
      assert_eq(children_by_slot(document, document.root, 2).length(), 1)
      assert_eq(
        descendants_by_rule(document, document.root, root_rule.rule.rule_id).length() >
        0,
        true,
      )
    }
    _ => abort("expected rule root")
  }
}

///|
test "cst query returns hidden trivia around visible tokens" {
  let fixture = any_cst_fixture_by_id("visitor-calc-hidden")
  let document = cst_document_for_fixture(
    fixture,
    cst_parser_hooks_for_fixture(fixture),
  )
  let plus_id = first_token_id_by_lexeme(document, "+")
  let leading = leading_hidden_tokens(document, plus_id)
  let trailing = trailing_hidden_tokens(document, plus_id)
  assert_eq(leading.length(), 1)
  assert_eq(trailing.length(), 1)
  assert_eq(leading[0].lexeme, " ")
  assert_eq(trailing[0].lexeme, " ")
}

///|
test "cst runtime records trailing-token recovery artifact" {
  let fixture = any_cst_fixture_by_id("trailing-tokens")
  let document = cst_document_for_fixture(
    fixture,
    cst_parser_hooks_for_fixture(fixture),
  )
  assert_eq(document.recovery_events.length(), 1)
  match document.recovery_events[0].kind {
    UnexpectedToken => ()
    _ => abort("expected unexpected-token recovery")
  }
  match node(document, document.root) {
    Rule(root_rule) => assert_eq(root_rule.recovered, true)
    _ => abort("expected rule root")
  }
}

///|
test "cst builder projects diagnostic-only parser failure" {
  let fixture = any_cst_fixture_by_id("parser-predicate")
  let document = cst_document_for_fixture(
    fixture,
    @antlr_runtime.ParserHostHooks::empty(),
  )
  assert_eq(document.recovery_events.length() > 0, true)
  match document.recovery_events[0].kind {
    MissingSubtree => ()
    _ => abort("expected missing-subtree recovery")
  }
}
