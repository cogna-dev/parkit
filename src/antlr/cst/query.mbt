///|
fn cst_copy_node_ids(values : Array[CstNodeId]) -> Array[CstNodeId] {
  let copied : Array[CstNodeId] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn cst_rule_children_or_abort(
  document : CstDocument,
  rule_node_id : CstNodeId,
) -> Array[CstChildEdge] {
  match document.nodes[rule_node_id.0] {
    Rule(rule_node) => cst_copy_child_edges(rule_node.children)
    _ => abort("expected rule node " + rule_node_id.0.to_string())
  }
}

///|
fn cst_descendants_by_rule_visit(
  document : CstDocument,
  node_id : CstNodeId,
  rule_id : Int,
  into : Array[CstNodeId],
) -> Unit {
  match document.nodes[node_id.0] {
    Rule(rule_node) =>
      for edge in rule_node.children {
        match document.nodes[edge.child.0] {
          Rule(child_rule) => {
            if child_rule.rule.rule_id == rule_id {
              into.push(edge.child)
            }
            cst_descendants_by_rule_visit(document, edge.child, rule_id, into)
          }
          _ => ()
        }
      }
    _ => ()
  }
}

///|
/// Resolve one node from the CST arena by stable identifier.
///
/// Example:
/// let node_value = node(document, document.root)
/// ignore(node_value)
///
/// Notes:
/// - The lookup uses direct arena indexing.
/// - Callers should only pass ids originating from the same `CstDocument`.
pub fn node(document : CstDocument, node_id : CstNodeId) -> CstNode {
  document.nodes[node_id.0]
}

///|
/// Resolve one token-table record from the CST document by stable identifier.
///
/// Example:
/// let token_value = token(document, CstTokenId(0))
/// ignore(token_value)
///
/// Notes:
/// - The lookup uses direct arena indexing.
/// - Synthetic recovery tokens remain addressable through the same table.
pub fn token(document : CstDocument, token_id : CstTokenId) -> CstTokenRecord {
  document.tokens[token_id.0]
}

///|
/// Return all child edges for one rule node in lexical order.
///
/// Example:
/// let edges = children(document, document.root)
/// inspect(edges.length() >= 0, content="true")
///
/// Notes:
/// - The result order matches source order, not label grouping.
/// - Passing a non-rule node id aborts immediately.
pub fn children(
  document : CstDocument,
  rule_node_id : CstNodeId,
) -> Array[CstChildEdge] {
  cst_rule_children_or_abort(document, rule_node_id)
}

///|
/// Return child edges for one rule node filtered by public label.
///
/// Example:
/// let edges = children_by_label(document, document.root, "left")
/// inspect(edges.length() >= 0, content="true")
///
/// Notes:
/// - Only exact label matches are returned.
/// - Unlabelled slots never match.
pub fn children_by_label(
  document : CstDocument,
  rule_node_id : CstNodeId,
  label : String,
) -> Array[CstChildEdge] {
  let filtered : Array[CstChildEdge] = []
  for edge in cst_rule_children_or_abort(document, rule_node_id) {
    match edge.slot.label {
      Some(edge_label) => if edge_label == label { filtered.push(edge) }
      None => ()
    }
  }
  filtered
}

///|
/// Return child edges for one rule node filtered by stable slot identifier.
///
/// Example:
/// let edges = children_by_slot(document, document.root, 0)
/// inspect(edges.length() >= 0, content="true")
///
/// Notes:
/// - Repeated occurrences of the same slot remain ordered by `occurrence_index`.
/// - Slot ids are local to one original rule alternative.
pub fn children_by_slot(
  document : CstDocument,
  rule_node_id : CstNodeId,
  slot_id : Int,
) -> Array[CstChildEdge] {
  let filtered : Array[CstChildEdge] = []
  for edge in cst_rule_children_or_abort(document, rule_node_id) {
    if edge.slot.slot_id == slot_id {
      filtered.push(edge)
    }
  }
  filtered
}

///|
/// Return descendant rule nodes whose public rule id matches `rule_id`.
///
/// Example:
/// let descendants = descendants_by_rule(document, document.root, 0)
/// inspect(descendants.length() >= 0, content="true")
///
/// Notes:
/// - The starting node itself is not included in the result.
/// - Traversal follows CST child edges, not recovery-event references.
pub fn descendants_by_rule(
  document : CstDocument,
  node_id : CstNodeId,
  rule_id : Int,
) -> Array[CstNodeId] {
  let descendants : Array[CstNodeId] = []
  cst_descendants_by_rule_visit(document, node_id, rule_id, descendants)
  cst_copy_node_ids(descendants)
}

///|
/// Return contiguous hidden/off-channel tokens immediately preceding one token.
///
/// Example:
/// let hidden = leading_hidden_tokens(document, CstTokenId(0))
/// inspect(hidden.length() >= 0, content="true")
///
/// Notes:
/// - The returned tokens are ordered lexically from left to right.
/// - Scanning stops at the previous visible token or the start of the token table.
pub fn leading_hidden_tokens(
  document : CstDocument,
  token_id : CstTokenId,
) -> Array[CstTokenRecord] {
  let reversed : Array[CstTokenRecord] = []
  let mut index = token_id.0 - 1
  while index >= 0 {
    let current = document.tokens[index]
    if cst_token_is_visible(current) {
      break
    }
    reversed.push(current)
    index = index - 1
  }
  let ordered : Array[CstTokenRecord] = []
  let mut reverse_index = reversed.length() - 1
  while reverse_index >= 0 && reversed.length() > 0 {
    ordered.push(reversed[reverse_index])
    if reverse_index == 0 {
      break
    }
    reverse_index = reverse_index - 1
  }
  ordered
}

///|
/// Return contiguous hidden/off-channel tokens immediately following one token.
///
/// Example:
/// let hidden = trailing_hidden_tokens(document, CstTokenId(0))
/// inspect(hidden.length() >= 0, content="true")
///
/// Notes:
/// - Scanning stops at the next visible token, including EOF.
/// - Hidden tokens are returned in lexical order.
pub fn trailing_hidden_tokens(
  document : CstDocument,
  token_id : CstTokenId,
) -> Array[CstTokenRecord] {
  let hidden : Array[CstTokenRecord] = []
  for index = token_id.0 + 1
      index < document.tokens.length()
      index = index + 1 {
    let current = document.tokens[index]
    if cst_token_is_visible(current) {
      break
    }
    hidden.push(current)
  }
  hidden
}

///|
/// Return the source span for one CST node.
///
/// Example:
/// let span = node_span(document, document.root)
/// ignore(span)
///
/// Notes:
/// - Rule, token, and error nodes all expose stable spans through this API.
/// - Parent pointers are intentionally not required for span lookup.
pub fn node_span(
  document : CstDocument,
  node_id : CstNodeId,
) -> @antlr.SourceSpan {
  match document.nodes[node_id.0] {
    Rule(rule_node) => rule_node.span
    Token(token_node) => token_node.span
    Error(error_node) => error_node.span
  }
}
