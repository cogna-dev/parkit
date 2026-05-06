///|
fn representative_fixture() -> @antlr_fixture.CstGoldenSnapshotFixture {
  for fixture in @antlr_fixture.representative_cst_snapshots() {
    if fixture.id == "hello-basic-local" {
      return fixture
    }
  }
  abort("expected hello-basic-local fixture")
}

///|
fn example_document() -> @antlr_cst.CstDocument {
  let fixture = representative_fixture()
  let report = @antlr.run_frontend_pipeline(fixture.source)
  if report.has_errors() {
    let diagnostics = report.all_diagnostics()
    if diagnostics.length() == 0 {
      abort("expected frontend success for example grammar")
    }
    abort(diagnostics[0].message)
  }
  let atn = match report.grammar_atn {
    Some(value) => value
    None => abort("expected runtime ATN for example grammar")
  }
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
    Ok(value) => value
    Err(error) => abort(error)
  }
}

///|
test "antlr example generated package stays usable" {
  let document = example_document()
  let info = grammar_info()
  assert_eq(info.grammar_name, "Hello")
  assert_eq(document_matches(document), true)
  let root = match lower_r_node(document, document.root) {
    Ok(value) => value
    Err(_) => abort("expected example lowering success")
  }
  match root {
    Alt1(fields) => assert_eq(fields.id_token.lexeme, "abc")
  }
}
