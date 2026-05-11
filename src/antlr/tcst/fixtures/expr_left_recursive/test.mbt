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
test "expr_left_recursive typed lowering preserves original grammar surface" {
  let fixture = representative_fixture_by_id("expr-left-recursive")
  let document = cst_document_for_fixture(fixture)
  assert_eq(document_matches(document), true)
  let info = grammar_info()
  assert_eq(info.grammar_name, "Expr")
  assert_eq(info.start_rule_name, "expr")

  let fields = match lower_root(document) {
    Ok(Add(value)) => value
    Ok(_) => abort("expected Add root node")
    Err(_) => abort("expected expr_left_recursive lowering success")
  }
  assert_eq(fields.plus_token.lexeme, "+")
  let left = fields.expr_1
  let right = fields.expr_2
  match left {
    Add(left_fields) => {
      assert_eq(left_fields.plus_token.lexeme, "+")
      match left_fields.expr_1 {
        Atom(atom_fields) => assert_eq(atom_fields.int_token.lexeme, "1")
        _ => abort("expected left-most atom 1")
      }
      match left_fields.expr_2 {
        Atom(atom_fields) => assert_eq(atom_fields.int_token.lexeme, "2")
        _ => abort("expected middle atom 2")
      }
    }
    _ => abort("expected nested Add node on the left")
  }
  match right {
    Atom(atom_fields) => assert_eq(atom_fields.int_token.lexeme, "3")
    _ => abort("expected right-most atom 3")
  }

  let query_node = match lower_expr_node(document, document.root) {
    Ok(value) => value
    Err(_) => abort("expected expr_left_recursive query lowering success")
  }
  match query_node.first_token() {
    Some(token) => assert_eq(token.lexeme, "1")
    None => abort("expected first token on expr_left_recursive node")
  }
  match query_node.last_token() {
    Some(token) => assert_eq(token.lexeme, "3")
    None => abort("expected last token on expr_left_recursive node")
  }
}
