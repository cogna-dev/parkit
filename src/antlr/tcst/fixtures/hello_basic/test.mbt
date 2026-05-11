///|
fn representative_fixture_by_id(
  fixture_id : String,
) -> @antlr_fixture.CstGoldenSnapshotFixture {
  for fixture in @antlr_fixture.representative_cst_snapshots() {
    if fixture.id == fixture_id {
      return fixture
    }
  }
  abort("expected representative fixture `" + fixture_id + "`")
}

///|
fn expect_runtime_atn(source : String) -> @antlr.GrammarAtn {
  let report = @antlr.run_frontend_pipeline(source)
  if report.has_errors() {
    let diagnostics = report.all_diagnostics()
    if diagnostics.length() == 0 {
      abort("expected frontend success for typed fixture")
    }
    abort(diagnostics[0].message)
  }
  match report.grammar_atn {
    Some(atn) => atn
    None => abort("expected runtime fixture ATN")
  }
}

///|
fn cst_document_for_fixture(
  fixture : @antlr_fixture.CstGoldenSnapshotFixture,
) -> @antlr_cst.CstDocument {
  let atn = expect_runtime_atn(fixture.source)
  let lexer_result = @antlr_runtime.lex_with_atn(
    atn,
    fixture.input,
    @antlr_runtime.LexerHostHooks::empty(),
  )
  if lexer_result.diagnostics.length() != 0 {
    abort(lexer_result.diagnostics[0].message)
  }
  let parsed = @antlr_runtime.parse_with_atn(
    atn,
    lexer_result.tokens,
    @antlr_runtime.ParserHostHooks::empty(),
  )
  match @antlr_cst.build_cst_document(atn, parsed) {
    Ok(document) => document
    Err(error) => abort(error)
  }
}

///|
fn copy_nodes(values : Array[@antlr_cst.CstNode]) -> Array[@antlr_cst.CstNode] {
  let copied : Array[@antlr_cst.CstNode] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn copy_tokens(
  values : Array[@antlr_cst.CstTokenRecord],
) -> Array[@antlr_cst.CstTokenRecord] {
  let copied : Array[@antlr_cst.CstTokenRecord] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn copy_recovery_events(
  values : Array[@antlr_cst.CstRecoveryEvent],
) -> Array[@antlr_cst.CstRecoveryEvent] {
  let copied : Array[@antlr_cst.CstRecoveryEvent] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn document_with_schema_version(
  document : @antlr_cst.CstDocument,
  schema_version : @antlr_cst.CstSchemaVersion,
) -> @antlr_cst.CstDocument {
  {
    schema_version,
    grammar: document.grammar,
    root: document.root,
    nodes: copy_nodes(document.nodes),
    tokens: copy_tokens(document.tokens),
    recovery_events: copy_recovery_events(document.recovery_events),
  }
}

///|
fn document_with_recovery_events(
  document : @antlr_cst.CstDocument,
  recovery_events : Array[@antlr_cst.CstRecoveryEvent],
) -> @antlr_cst.CstDocument {
  {
    schema_version: document.schema_version,
    grammar: document.grammar,
    root: document.root,
    nodes: copy_nodes(document.nodes),
    tokens: copy_tokens(document.tokens),
    recovery_events,
  }
}

///|
test "hello_basic typed lowering succeeds" {
  let fixture = representative_fixture_by_id("hello-basic-local")
  let document = cst_document_for_fixture(fixture)
  assert_eq(document_matches(document), true)
  let info = grammar_info()
  assert_eq(info.grammar_name, "Hello")
  assert_eq(info.start_rule_name, "r")
  assert_eq(info.grammar_fingerprint.length() > 0, true)

  let fields = match lower_root(document) {
    Ok(Alt1(value)) => value
    Err(_) => abort("expected hello_basic lowering success")
  }
  assert_eq(fields.hello_token.lexeme, "hello")
  assert_eq(fields.id_token.lexeme, "abc")

  let query_node = match lower_r_node(document, document.root) {
    Ok(value) => value
    Err(_) => abort("expected hello_basic query lowering success")
  }
  match query_node.first_token() {
    Some(token) => assert_eq(token.lexeme, "hello")
    None => abort("expected first token on hello_basic node")
  }
  match query_node.last_token() {
    Some(token) => assert_eq(token.lexeme, "abc")
    None => abort("expected last token on hello_basic node")
  }
}

///|
test "hello_basic typed lowering rejects schema drift" {
  let fixture = representative_fixture_by_id("hello-basic-local")
  let document = cst_document_for_fixture(fixture)
  let drifted = document_with_schema_version(
    document,
    @antlr_cst.CstSchemaVersion(2),
  )
  assert_eq(document_matches(drifted), false)
  match lower_root(drifted) {
    Err(SchemaVersionMismatch(expected, actual)) => {
      assert_eq(expected, 1)
      assert_eq(actual, 2)
    }
    _ => abort("expected hello_basic schema drift rejection")
  }
}

///|
test "hello_basic typed lowering rejects recovery artifacts" {
  let fixture = representative_fixture_by_id("hello-basic-local")
  let document = cst_document_for_fixture(fixture)
  let with_recovery = document_with_recovery_events(document, [
    {
      kind: @antlr_cst.UnexpectedToken,
      detail_kind: "unexpected-token",
      span: @antlr_cst.node_span(document, document.root),
      node: Some(document.root),
      token: None,
      visible_offset: 0,
      message: Some("synthetic recovery artifact"),
    },
  ])
  assert_eq(document_matches(with_recovery), true)
  match lower_root(with_recovery) {
    Err(RecoveryArtifactPresent(rule_name, node_id)) => {
      assert_eq(rule_name, "r")
      assert_eq(node_id.0, document.root.0)
    }
    _ => abort("expected hello_basic recovery rejection")
  }
}

///|
test "hello_basic parse returns typed root" {
  let fixture = representative_fixture_by_id("hello-basic-local")
  let fields = match parse(fixture.input) {
    Ok(Alt1(value)) => value
    Err(error) => abort(error)
  }
  assert_eq(fields.hello_token.lexeme, "hello")
  assert_eq(fields.id_token.lexeme, "abc")
}

///|
test "hello_basic parse rejects invalid input" {
  match parse("oops") {
    Ok(_) => abort("expected parse failure")
    Err(message) => assert_eq(message.length() > 0, true)
  }
}
