///|
fn expect_runtime_atn(source : String) -> @antlr.GrammarAtn {
  let report = @antlr.run_frontend_pipeline(source)
  if report.has_errors() {
    let diagnostics = report.all_diagnostics()
    if diagnostics.length() == 0 {
      abort("expected frontend success for runtime fixture")
    }
    abort(diagnostics[0].message)
  }
  match report.grammar_atn {
    Some(atn) => atn
    None => abort("expected runtime fixture ATN")
  }
}

///|
fn hooks_for_fixture(
  fixture : @antlr_fixture.LexerGoldenSnapshotFixture,
) -> LexerHostHooks {
  let mut hooks = LexerHostHooks::empty()
  for predicate in fixture.true_predicates {
    hooks = hooks.with_predicate(predicate, true)
  }
  for binding in fixture.action_labels {
    hooks = hooks.with_action(binding.text, binding.label)
  }
  hooks
}

///|
fn representative_lexer_fixture_by_id(
  fixture_id : String,
) -> @antlr_fixture.LexerGoldenSnapshotFixture {
  for fixture in @antlr_fixture.representative_lexer_snapshots() {
    if fixture.id == fixture_id {
      return fixture
    }
  }
  abort("expected representative lexer fixture `" + fixture_id + "`")
}

///|
fn any_lexer_fixture_by_id(
  fixture_id : String,
) -> @antlr_fixture.LexerGoldenSnapshotFixture {
  for fixture in @antlr_fixture.representative_lexer_snapshots() {
    if fixture.id == fixture_id {
      return fixture
    }
  }
  for fixture in @antlr_fixture.upstream_lexer_snapshots() {
    if fixture.id == fixture_id {
      return fixture
    }
  }
  abort("expected lexer fixture `" + fixture_id + "`")
}

///|
fn frontend_fixture_by_id(
  fixture_id : String,
) -> @antlr_fixture.UpstreamGrammarFixture {
  for fixture in @antlr_fixture.supported_frontend_fixtures() {
    if fixture.id == fixture_id {
      return fixture
    }
  }
  abort("expected frontend fixture `" + fixture_id + "`")
}

///|
fn grammar_header_end(source : String) -> Int {
  let mut index = 0
  while index < source.length() {
    if source.get_char(index).unwrap() == ';' {
      return index + 1
    }
    index = index + 1
  }
  abort("expected grammar header terminator")
}

///|
fn grammar_body_without_imports(source : String) -> String {
  let header_end = grammar_header_end(source)
  let body = source[header_end:source.length()].to_string()
  let kept_lines : Array[String] = []
  for line in body.split("\n").map(line => line.to_string()).to_array() {
    if !line.trim().has_prefix("import ") {
      kept_lines.push(line)
    }
  }
  kept_lines.join("\n").trim().to_string()
}

///|
fn flatten_composite_lexer_source(
  main_fixture_id : String,
  imported_fixture_ids : Array[String],
) -> String {
  let main_source = frontend_fixture_by_id(main_fixture_id).source
  let header_end = grammar_header_end(main_source)
  let header = main_source[0:header_end].to_string()
  let flattened_bodies : Array[String] = []
  for fixture_id in imported_fixture_ids {
    flattened_bodies.push(
      grammar_body_without_imports(frontend_fixture_by_id(fixture_id).source),
    )
  }
  flattened_bodies.push(grammar_body_without_imports(main_source))
  header + "\n\n" + flattened_bodies.join("\n\n") + "\n"
}

///|
fn imports_standard_lexer_source() -> String {
  flatten_composite_lexer_source("maven-imports-lexer", [
    "maven-imports-base-lexer", "maven-imports-base-lexer-2",
  ])
}

///|
fn imports_custom_lexer_source() -> String {
  flatten_composite_lexer_source("maven-imports-custom-lexer", [
    "maven-imports-custom-base-lexer",
  ])
}

///|
fn assert_lexer_snapshot(
  fixture : @antlr_fixture.LexerGoldenSnapshotFixture,
  via_serialized_atn : Bool,
) -> Unit {
  let atn = expect_runtime_atn(fixture.source)
  let hooks = hooks_for_fixture(fixture)
  let actual = if via_serialized_atn {
    let serialized_atn = @antlr.serialize_grammar_atn(atn)
    match lex_serialized_atn(serialized_atn, fixture.input, hooks) {
      Ok(result) => serialize_lexer_run(result)
      Err(error) => abort(error)
    }
  } else {
    serialize_lexer_run(lex_with_atn(atn, fixture.input, hooks))
  }
  if actual != fixture.expected_serialized_run {
    println(actual)
    abort(
      "lexer golden snapshot mismatch for `" +
      fixture.id +
      "`" +
      (if via_serialized_atn { " via serialized ATN" } else { "" }),
    )
  }
}

///|
test "lexer runtime matches representative golden snapshots" {
  for fixture in @antlr_fixture.representative_lexer_snapshots() {
    assert_lexer_snapshot(fixture, false)
  }
}

///|
test "serialized atn entry point matches representative lexer golden snapshots" {
  for fixture in @antlr_fixture.representative_lexer_snapshots() {
    assert_lexer_snapshot(fixture, true)
  }
}

///|
test "lexer runtime matches upstream golden snapshots" {
  for fixture in @antlr_fixture.upstream_lexer_snapshots() {
    assert_lexer_snapshot(fixture, false)
  }
}

///|
test "lexer runtime records dfa entries on implicit literal fixture" {
  let fixture = representative_lexer_fixture_by_id("hello-basic")
  let result = lex_with_atn(
    expect_runtime_atn(fixture.source),
    fixture.input,
    hooks_for_fixture(fixture),
  )
  assert_eq(result.dfa.entries.length() > 0, true)
  assert_eq(result.dfa.entries[0].matched_length >= 0, true)
}

///|
test "lexer runtime reports active mode in diagnostics when predicate rejects" {
  let fixture = representative_lexer_fixture_by_id("lexer-command-modes")
  let result = lex_with_atn(
    expect_runtime_atn(fixture.source),
    "/*x",
    LexerHostHooks::empty(),
  )
  assert_eq(result.diagnostics.length(), 1)
  assert_eq(
    result.diagnostics[0].message,
    "no viable lexer alternative in mode `COMMENT_MODE`",
  )
  assert_eq(result.tokens.length(), 1)
  assert_eq(result.tokens[0].is_eof, true)
  assert_eq(result.tokens[0].start_mode_name, "COMMENT_MODE")
}

///|
test "lexer runtime executes not-set transitions against excluded delimiters" {
  let fixture = representative_lexer_fixture_by_id("not-set-text")
  let result = lex_with_atn(
    expect_runtime_atn(fixture.source),
    fixture.input,
    hooks_for_fixture(fixture),
  )
  assert_eq(result.tokens.length(), 5)
  assert_eq(result.tokens[0].token_name, "TEXT")
  assert_eq(result.tokens[0].text, "abc")
  assert_eq(result.tokens[1].token_name, "LT")
  assert_eq(result.tokens[2].token_name, "AMP")
  assert_eq(result.tokens[3].token_name, "TEXT")
  assert_eq(result.tokens[3].text, "xy")
}

///|
test "lexer runtime keeps hidden-channel tokens from combined grammars" {
  let fixture = any_lexer_fixture_by_id("visitor-calc")
  let result = lex_with_atn(
    expect_runtime_atn(fixture.source),
    fixture.input,
    hooks_for_fixture(fixture),
  )
  assert_eq(result.tokens.length(), 6)
  assert_eq(result.tokens[1].token_name, "WS")
  assert_eq(result.tokens[1].channel_name, "HIDDEN")
  assert_eq(result.tokens[3].channel_name, "HIDDEN")
}

///|
test "lexer runtime emits whitespace on default channel when no command overrides it" {
  let fixture = any_lexer_fixture_by_id("swift-lexer-b")
  let result = lex_with_atn(
    expect_runtime_atn(fixture.source),
    fixture.input,
    hooks_for_fixture(fixture),
  )
  assert_eq(result.tokens.length(), 8)
  assert_eq(result.tokens[1].token_name, "WS")
  assert_eq(result.tokens[1].channel_name, "DEFAULT_TOKEN_CHANNEL")
  assert_eq(result.tokens[2].token_name, "INT")
  assert_eq(result.tokens[6].token_name, "SEMI")
}

///|
test "composite lexer mirror runs importsStandard lexer chain" {
  let result = lex_with_atn(
    expect_runtime_atn(imports_standard_lexer_source()),
    "<!--x-->abc<![CDATA[y]]>",
    LexerHostHooks::empty(),
  )
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.tokens.length(), 4)
  assert_eq(result.tokens[0].token_name, "Comment")
  assert_eq(result.tokens[0].text, "<!--x-->")
  assert_eq(result.tokens[1].token_name, "TEXT")
  assert_eq(result.tokens[1].text, "abc")
  assert_eq(result.tokens[2].token_name, "CDSect")
  assert_eq(result.tokens[2].text, "<![CDATA[y]]>")
  assert_eq(result.tokens[3].is_eof, true)
}

///|
test "composite lexer mirror runs importsCustom lexer chain" {
  let result = lex_with_atn(
    expect_runtime_atn(imports_custom_lexer_source()),
    "<!--x-->abc",
    LexerHostHooks::empty(),
  )
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.tokens.length(), 3)
  assert_eq(result.tokens[0].token_name, "Comment")
  assert_eq(result.tokens[0].text, "<!--x-->")
  assert_eq(result.tokens[1].token_name, "TEXT")
  assert_eq(result.tokens[1].text, "abc")
  assert_eq(result.tokens[2].is_eof, true)
}
