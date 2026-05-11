///|
fn parser_lexer_hooks_for_fixture(
  fixture : @antlr_fixture.ParserGoldenSnapshotFixture,
) -> LexerHostHooks {
  let mut hooks = LexerHostHooks::empty()
  for predicate in fixture.lexer_true_predicates {
    hooks = hooks.with_predicate(predicate, true)
  }
  for binding in fixture.lexer_action_labels {
    hooks = hooks.with_action(binding.text, binding.label)
  }
  hooks
}

///|
fn parser_hooks_for_fixture(
  fixture : @antlr_fixture.ParserGoldenSnapshotFixture,
) -> ParserHostHooks {
  let mut hooks = ParserHostHooks::empty()
  for predicate in fixture.parser_true_predicates {
    hooks = hooks.with_predicate(predicate, true)
  }
  for binding in fixture.parser_action_labels {
    hooks = hooks.with_action(binding.text, binding.label)
  }
  hooks
}

///|
fn parser_runtime_fixture_by_id(
  fixture_id : String,
) -> @antlr_fixture.ParserGoldenSnapshotFixture {
  for fixture in @antlr_fixture.representative_parser_snapshots() {
    if fixture.id == fixture_id {
      return fixture
    }
  }
  for fixture in @antlr_fixture.upstream_parser_snapshots() {
    if fixture.id == fixture_id {
      return fixture
    }
  }
  abort("expected parser fixture `" + fixture_id + "`")
}

///|
fn parser_lexer_result_or_abort(
  fixture : @antlr_fixture.ParserGoldenSnapshotFixture,
) -> LexerRunResult {
  let atn = expect_runtime_atn(fixture.source)
  let lexer_result = lex_with_atn(
    atn,
    fixture.input,
    parser_lexer_hooks_for_fixture(fixture),
  )
  if lexer_result.diagnostics.length() != 0 {
    abort(lexer_result.diagnostics[0].message)
  }
  lexer_result
}

///|
fn assert_parser_snapshot(
  fixture : @antlr_fixture.ParserGoldenSnapshotFixture,
  via_serialized_atn : Bool,
) -> Unit {
  let atn = expect_runtime_atn(fixture.source)
  let lexer_result = parser_lexer_result_or_abort(fixture)
  let hooks = parser_hooks_for_fixture(fixture)
  let actual = if via_serialized_atn {
    let serialized_atn = @antlr.serialize_grammar_atn(atn)
    match parse_serialized_atn(serialized_atn, lexer_result.tokens, hooks) {
      Ok(result) => serialize_parser_run(result)
      Err(error) => abort(error)
    }
  } else {
    serialize_parser_run(parse_with_atn(atn, lexer_result.tokens, hooks))
  }
  if actual != fixture.expected_serialized_run {
    println(actual)
    abort(
      "parser golden snapshot mismatch for `" +
      fixture.id +
      "`" +
      (if via_serialized_atn { " via serialized ATN" } else { "" }),
    )
  }
}

///|
test "parser runtime matches representative golden snapshots" {
  for fixture in @antlr_fixture.representative_parser_snapshots() {
    assert_parser_snapshot(fixture, false)
  }
}

///|
test "serialized atn parser entry matches representative golden snapshots" {
  for fixture in @antlr_fixture.representative_parser_snapshots() {
    assert_parser_snapshot(fixture, true)
  }
}

///|
test "parser runtime matches upstream golden snapshots" {
  for fixture in @antlr_fixture.upstream_parser_snapshots() {
    assert_parser_snapshot(fixture, false)
  }
}

///|
test "parser runtime records fallback on predictive-fallback fixture" {
  let fixture = parser_runtime_fixture_by_id("predictive-fallback")
  let result = parse_with_atn(
    expect_runtime_atn(fixture.source),
    parser_lexer_result_or_abort(fixture).tokens,
    parser_hooks_for_fixture(fixture),
  )
  assert_eq(result.full_context_fallbacks > 0, true)
  assert_eq(result.dfa.entries.length() > 0, true)
}

///|
test "parser runtime rejects missing parser predicate hook" {
  let fixture = parser_runtime_fixture_by_id("parser-predicate")
  let result = parse_with_atn(
    expect_runtime_atn(fixture.source),
    parser_lexer_result_or_abort(fixture).tokens,
    ParserHostHooks::empty(),
  )
  assert_eq(result.success, false)
  assert_eq(result.diagnostics.length() > 0, true)
}

///|
test "parser runtime records trailing-token recovery" {
  let fixture = parser_runtime_fixture_by_id("trailing-tokens")
  let result = parse_with_atn(
    expect_runtime_atn(fixture.source),
    parser_lexer_result_or_abort(fixture).tokens,
    parser_hooks_for_fixture(fixture),
  )
  assert_eq(result.recovery_events.length(), 1)
  assert_eq(result.success, false)
  assert_eq(result.recovery_events[0].token_name, Some("ID"))
}

///|
test "composite parser mirror parses importsStandard token vocabulary chain" {
  let lexer_result = lex_with_atn(
    expect_runtime_atn(imports_standard_lexer_source()),
    "<!--x-->",
    LexerHostHooks::empty(),
  )
  assert_eq(lexer_result.diagnostics.length(), 0)
  let result = parse_with_atn(
    expect_runtime_atn(frontend_fixture_by_id("maven-imports-parser").source),
    lexer_result.tokens,
    ParserHostHooks::empty(),
  )
  assert_eq(result.success, true)
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.recovery_events.length(), 0)
  assert_eq(result.start_rule_name, "document")
  assert_eq(result.tokens[0].token_name, "Comment")
  assert_eq(result.tokens[1].token_name, "EOF")
  assert_eq(result.dfa.entries.length() > 0, true)
}

///|
test "composite parser mirror parses importsCustom token vocabulary chain" {
  let lexer_result = lex_with_atn(
    expect_runtime_atn(imports_custom_lexer_source()),
    "<!--x-->",
    LexerHostHooks::empty(),
  )
  assert_eq(lexer_result.diagnostics.length(), 0)
  let result = parse_with_atn(
    expect_runtime_atn(
      frontend_fixture_by_id("maven-imports-custom-parser").source,
    ),
    lexer_result.tokens,
    ParserHostHooks::empty(),
  )
  assert_eq(result.success, true)
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.recovery_events.length(), 0)
  assert_eq(result.start_rule_name, "document")
  assert_eq(result.tokens[0].token_name, "Comment")
  assert_eq(result.tokens[1].token_name, "EOF")
  assert_eq(result.dfa.entries.length() > 0, true)
}
