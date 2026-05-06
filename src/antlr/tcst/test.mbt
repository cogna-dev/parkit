///|
fn representative_fixture_by_id(
  fixture_id : String,
) -> @antlr_fixture.TcstFixture {
  for fixture in @antlr_fixture.representative_tcst_fixtures() {
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
  fixture : @antlr_fixture.TcstFixture,
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
fn grammar_info_for_document(
  document : @antlr_cst.CstDocument,
) -> TypedGrammarInfo {
  {
    grammar_name: document.grammar.grammar_name,
    grammar_kind: document.grammar.grammar_kind,
    start_rule_name: document.grammar.start_rule.rule_name,
    grammar_fingerprint: document.grammar.fingerprint.0,
    cst_schema_version: document.schema_version.0,
  }
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
fn document_with_grammar(
  document : @antlr_cst.CstDocument,
  grammar : @antlr_cst.CstGrammarInfo,
) -> @antlr_cst.CstDocument {
  {
    schema_version: document.schema_version,
    grammar,
    root: document.root,
    nodes: copy_nodes(document.nodes),
    tokens: copy_tokens(document.tokens),
    recovery_events: copy_recovery_events(document.recovery_events),
  }
}

///|
fn read_text_or_abort(path : String) -> String {
  @fs.read_file_to_string(path) catch {
    _ => abort("failed to read `" + path + "`")
  }
}

///|
fn normalize_generated_file_text(text : String) -> String {
  if text.length() > 0 && text[text.length() - 1:text.length()] == "\n" {
    return text[0:text.length() - 1].to_string()
  }
  text
}

///|
fn constructor_by_name(
  rule : TypedRuleModel,
  constructor_name : String,
) -> TypedConstructorModel {
  for case_model in rule.constructors {
    if case_model.constructor_name == constructor_name {
      return case_model
    }
  }
  abort(
    "expected constructor `" +
    constructor_name +
    "` on rule `" +
    rule.rule_name +
    "`",
  )
}

///|
fn field_by_name(
  constructor_model : TypedConstructorModel,
  field_name : String,
) -> TypedFieldModel {
  for field in constructor_model.fields {
    if field.field_name == field_name {
      return field
    }
  }
  abort(
    "expected field `" +
    field_name +
    "` on constructor `" +
    constructor_model.constructor_name +
    "`",
  )
}

///|
fn expect_generated_files_match(
  fixture_id : String,
  package_name : String,
  output_dir : String,
) -> Unit {
  let fixture = representative_fixture_by_id(fixture_id)
  let files = match generate_typed_package(fixture.source, package_name) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  if files.length() != 7 {
    abort("expected seven generated files for `" + fixture_id + "`")
  }
  for file in files {
    let expected_path = output_dir + "/" + file.relative_path
    let actual = normalize_generated_file_text(
      read_text_or_abort(expected_path),
    )
    if normalize_generated_file_text(file.content) != actual {
      abort("generated file drift for `" + expected_path + "`")
    }
  }
}

///|
test "typed package model preserves expr left-recursive public surface" {
  let fixture = representative_fixture_by_id("expr-left-recursive")
  let model = match
    build_typed_package_model(
      fixture.source,
      "cogna-dev/parkit/antlr/tcst/fixtures/expr_left_recursive",
    ) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  assert_eq(model.root_rule_name, "expr")
  assert_eq(model.rules.length(), 1)
  let rule = model.rules.get(0).unwrap()
  assert_eq(rule.rule_name, "expr")
  let add_case = constructor_by_name(rule, "Add")
  assert_eq(add_case.fields.length(), 3)
  let expr_1_field = add_case.fields.get(0).unwrap()
  assert_eq(expr_1_field.field_name, "expr_1")
  match expr_1_field.kind {
    RuleNodeField(rule_name) => assert_eq(rule_name, "expr")
    _ => abort("expected expr_1 to remain a rule field")
  }
  let plus_field = add_case.fields.get(1).unwrap()
  assert_eq(plus_field.field_name, "plus_token")
  match plus_field.kind {
    TokenField(symbolic_name, literal_name) => {
      assert_eq(symbolic_name, None)
      assert_eq(literal_name, Some("'+'"))
    }
    _ => abort("expected plus_token to remain a literal token field")
  }
  let expr_2_field = add_case.fields.get(2).unwrap()
  assert_eq(expr_2_field.field_name, "expr_2")
  match expr_2_field.kind {
    RuleNodeField(rule_name) => assert_eq(rule_name, "expr")
    _ => abort("expected expr_2 to remain a rule field")
  }
  let atom_case = constructor_by_name(rule, "Atom")
  assert_eq(atom_case.fields.length(), 1)
  assert_eq(atom_case.fields.get(0).unwrap().field_name, "int_token")
}

///|
test "typed package model preserves option array and non-empty cardinality" {
  let fixture = representative_fixture_by_id("cardinality-mix")
  let model = match
    build_typed_package_model(
      fixture.source,
      "cogna-dev/parkit/antlr/tcst/fixtures/cardinality_mix",
    ) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  assert_eq(model.root_rule_name, "root")
  assert_eq(model.rules.length(), 1)
  let rule = model.rules.get(0).unwrap()
  assert_eq(rule.rule_name, "root")
  let alt1 = constructor_by_name(rule, "Alt1")
  assert_eq(alt1.fields.length(), 3)

  let maybe_field = field_by_name(alt1, "maybe")
  match maybe_field.cardinality {
    Optional => ()
    _ => abort("expected maybe field to remain optional")
  }
  match maybe_field.kind {
    TokenField(Some(symbolic_name), None) => assert_eq(symbolic_name, "MAYBE")
    _ => abort("expected maybe field to remain a MAYBE token field")
  }

  let many_field = field_by_name(alt1, "many")
  match many_field.cardinality {
    Repeated => ()
    _ => abort("expected many field to remain repeated")
  }
  match many_field.kind {
    TokenField(Some(symbolic_name), None) => assert_eq(symbolic_name, "ITEM")
    _ => abort("expected many field to remain an ITEM token field")
  }

  let some_field = field_by_name(alt1, "some")
  match some_field.cardinality {
    NonEmptyRepeated => ()
    _ => abort("expected some field to remain non-empty repeated")
  }
  match some_field.kind {
    TokenField(Some(symbolic_name), None) => assert_eq(symbolic_name, "REQ")
    _ => abort("expected some field to remain a REQ token field")
  }
}

///|
test "strict lowering runtime rejects schema and fingerprint drift" {
  let fixture = representative_fixture_by_id("hello-basic-local")
  let document = cst_document_for_fixture(fixture)
  let grammar_info = grammar_info_for_document(document)

  match
    checked_root_rule(
      document_with_schema_version(document, @antlr_cst.CstSchemaVersion(2)),
      grammar_info,
    ) {
    Err(SchemaVersionMismatch(expected, actual)) => {
      assert_eq(expected, 1)
      assert_eq(actual, 2)
    }
    _ => abort("expected schema drift to be rejected")
  }

  let drifted_grammar : @antlr_cst.CstGrammarInfo = {
    grammar_name: document.grammar.grammar_name,
    grammar_kind: document.grammar.grammar_kind,
    start_rule: document.grammar.start_rule,
    fingerprint: @antlr_cst.CstGrammarFingerprint("fingerprint-drift"),
  }
  match
    checked_root_rule(
      document_with_grammar(document, drifted_grammar),
      grammar_info,
    ) {
    Err(GrammarFingerprintMismatch(expected, actual)) => {
      assert_eq(expected, grammar_info.grammar_fingerprint)
      assert_eq(actual, "fingerprint-drift")
    }
    _ => abort("expected fingerprint drift to be rejected")
  }
}

///|
test "strict lowering runtime rejects node alternative and token mismatches" {
  let hello_fixture = representative_fixture_by_id("hello-basic-local")
  let hello_document = cst_document_for_fixture(hello_fixture)
  let hello_handle = match
    checked_rule(hello_document, hello_document.root, "r") {
    Ok(value) => value
    Err(_) => abort("expected checked hello root rule")
  }
  let hello_child = @antlr_cst.children(hello_document, hello_document.root)[0].child
  match checked_rule(hello_document, hello_child, "r") {
    Err(NodeKindMismatch(expected, actual, node_id)) => {
      assert_eq(expected, "rule:r")
      assert_eq(actual, "token")
      assert_eq(node_id.0, hello_child.0)
    }
    _ => abort("expected token node to fail rule check")
  }
  match
    token_children_for_slot(hello_document, hello_handle, 0, Some("ID"), None) {
    Err(TokenKindMismatch(expected, actual, node_id)) => {
      assert_eq(expected, "ID")
      assert_eq(actual, Some("'hello'"))
      assert_eq(node_id.0, hello_child.0)
    }
    _ => abort("expected token-kind mismatch on hello slot")
  }

  let expr_fixture = representative_fixture_by_id("expr-left-recursive")
  let expr_document = cst_document_for_fixture(expr_fixture)
  let expr_handle = match
    checked_rule(expr_document, expr_document.root, "expr") {
    Ok(value) => value
    Err(_) => abort("expected checked expr root rule")
  }
  match checked_alternative(expr_handle, [2]) {
    Err(AlternativeMismatch(rule_name, expected, actual, node_id)) => {
      assert_eq(rule_name, "expr")
      assert_eq(expected.length(), 1)
      assert_eq(expected[0], 2)
      assert_eq(actual, Some(1))
      assert_eq(node_id.0, expr_document.root.0)
    }
    _ => abort("expected alternative mismatch on expr root")
  }
}

///|
test "generated hello_basic fixture files stay in sync" {
  expect_generated_files_match(
    "hello-basic-local", "cogna-dev/parkit/antlr/tcst/fixtures/hello_basic", "src/antlr/tcst/fixtures/hello_basic",
  )
}

///|
test "generated expr_left_recursive fixture files stay in sync" {
  expect_generated_files_match(
    "expr-left-recursive", "cogna-dev/parkit/antlr/tcst/fixtures/expr_left_recursive",
    "src/antlr/tcst/fixtures/expr_left_recursive",
  )
}

///|
test "generated cardinality_mix fixture files stay in sync" {
  expect_generated_files_match(
    "cardinality-mix", "cogna-dev/parkit/antlr/tcst/fixtures/cardinality_mix", "src/antlr/tcst/fixtures/cardinality_mix",
  )
}
