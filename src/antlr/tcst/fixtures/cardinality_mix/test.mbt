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
fn copy_child_edges(
  values : Array[@antlr_cst.CstChildEdge],
) -> Array[@antlr_cst.CstChildEdge] {
  let copied : Array[@antlr_cst.CstChildEdge] = []
  for value in values {
    copied.push(value)
  }
  copied
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
fn root_rule_or_abort(
  document : @antlr_cst.CstDocument,
) -> @antlr_cst.CstRuleNode {
  match @antlr_cst.node(document, document.root) {
    @antlr_cst.Rule(rule_node) => rule_node
    _ => abort("expected root rule node")
  }
}

///|
fn document_with_root_rule(
  document : @antlr_cst.CstDocument,
  root_rule : @antlr_cst.CstRuleNode,
) -> @antlr_cst.CstDocument {
  let nodes = copy_nodes(document.nodes)
  nodes[document.root.0] = @antlr_cst.Rule(root_rule)
  {
    schema_version: document.schema_version,
    grammar: document.grammar,
    root: document.root,
    nodes,
    tokens: copy_tokens(document.tokens),
    recovery_events: copy_recovery_events(document.recovery_events),
  }
}

///|
test "cardinality_mix typed lowering preserves optional repeated and non-empty fields" {
  let fixture = representative_fixture_by_id("cardinality-mix")
  let document = cst_document_for_fixture(fixture)
  assert_eq(document_matches(document), true)
  let info = grammar_info()
  assert_eq(info.grammar_name, "CardinalityMix")
  assert_eq(info.start_rule_name, "root")

  let fields = match lower_root(document) {
    Ok(Alt1(value)) => value
    Err(_) => abort("expected cardinality_mix lowering success")
  }
  match fields.maybe {
    Some(token) => assert_eq(token.lexeme, "m")
    None => abort("expected maybe token")
  }
  assert_eq(fields.many.length(), 2)
  assert_eq(fields.many[0].lexeme, "i")
  assert_eq(fields.many[1].lexeme, "i")
  assert_eq(fields.some.head.lexeme, "r")
  assert_eq(fields.some.tail.length(), 1)
  assert_eq(fields.some.tail[0].lexeme, "r")
  let final_record = @antlr_cst.token(document, fields.some.tail[0].token_id)
  assert_eq(
    fields.some.tail[0].span.start.offset,
    final_record.span.start.offset,
  )
  assert_eq(fields.some.tail[0].span.end.offset, final_record.span.end.offset)

  let query_node = match lower_root_node(document, document.root) {
    Ok(value) => value
    Err(_) => abort("expected cardinality_mix query lowering success")
  }
  let cst_span = @antlr_cst.node_span(document, document.root)
  assert_eq(query_node.span().start.offset, cst_span.start.offset)
  assert_eq(query_node.span().end.offset, cst_span.end.offset)
  match query_node.first_token() {
    Some(token) => assert_eq(token.lexeme, "m")
    None => abort("expected first token on cardinality_mix node")
  }
  match query_node.last_token() {
    Some(token) => assert_eq(token.lexeme, "r")
    None => abort("expected last token on cardinality_mix node")
  }
}

///|
test "cardinality_mix typed lowering rejects duplicate optional child" {
  let fixture = representative_fixture_by_id("cardinality-mix")
  let document = cst_document_for_fixture(fixture)
  let root_rule = root_rule_or_abort(document)
  let children = copy_child_edges(root_rule.children)
  let maybe_edge = children[0]
  children.push({
    child: maybe_edge.child,
    slot: maybe_edge.slot,
    occurrence_index: 1,
    recovered: false,
  })
  let mutated = document_with_root_rule(document, {
    rule: root_rule.rule,
    alternative: root_rule.alternative,
    span: root_rule.span,
    children,
    recovered: root_rule.recovered,
  })
  match lower_root(mutated) {
    Err(CardinalityViolation(rule_name, slot_id, expected, actual, node_id)) => {
      assert_eq(rule_name, "root")
      assert_eq(slot_id, 0)
      assert_eq(expected, "optional")
      assert_eq(actual, 2)
      assert_eq(node_id.0, document.root.0)
    }
    _ => abort("expected duplicate optional child rejection")
  }
}

///|
test "cardinality_mix typed lowering rejects missing non-empty child" {
  let fixture = representative_fixture_by_id("cardinality-mix")
  let document = cst_document_for_fixture(fixture)
  let root_rule = root_rule_or_abort(document)
  let children : Array[@antlr_cst.CstChildEdge] = []
  for edge in root_rule.children {
    if edge.slot.slot_id != 2 {
      children.push(edge)
    }
  }
  let mutated = document_with_root_rule(document, {
    rule: root_rule.rule,
    alternative: root_rule.alternative,
    span: root_rule.span,
    children,
    recovered: root_rule.recovered,
  })
  match lower_root(mutated) {
    Err(RequiredChildMissing(rule_name, slot_id, field_name, node_id)) => {
      assert_eq(rule_name, "root")
      assert_eq(slot_id, 2)
      assert_eq(field_name, "some")
      assert_eq(node_id.0, document.root.0)
    }
    _ => abort("expected missing non-empty child rejection")
  }
}
