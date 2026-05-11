///|
/// Stable shape categories for the Phase 3 prediction-context arena.
pub(all) enum PredictionContextKind {
  EmptyPredictionContext
  SingletonPredictionContext
  MergedPredictionContext
}

///|
/// One interned prediction-context node used by parser configs and traces.
pub struct PredictionContextNode {
  context_id : Int
  kind : PredictionContextKind
  return_state_id : Int?
  parent_ids : Array[Int]
}

///|
/// Shared arena storing interned prediction-context nodes.
pub struct PredictionContextArena {
  nodes : Array[PredictionContextNode]
}

///|
fn parser_context_or_abort(
  arena : PredictionContextArena,
  context_id : Int,
) -> PredictionContextNode {
  for node in arena.nodes {
    if node.context_id == context_id {
      return node
    }
  }
  abort("expected prediction context `" + context_id.to_string() + "`")
}

///|
fn parser_is_singleton_context(kind : PredictionContextKind) -> Bool {
  match kind {
    SingletonPredictionContext => true
    _ => false
  }
}

///|
fn parser_render_context(
  arena : PredictionContextArena,
  context_id : Int,
) -> String {
  let node = parser_context_or_abort(arena, context_id)
  match node.kind {
    EmptyPredictionContext => "$"
    SingletonPredictionContext => {
      let return_state_text = match node.return_state_id {
        Some(return_state_id) => return_state_id.to_string()
        None => "-"
      }
      parser_render_context(arena, node.parent_ids[0]) +
      "->" +
      return_state_text
    }
    MergedPredictionContext => {
      let rendered : Array[String] = []
      for parent_id in node.parent_ids {
        rendered.push(parser_render_context(arena, parent_id))
      }
      "(" + rendered.join("&") + ")"
    }
  }
}

///|
fn parser_prediction_context_child(
  arena : PredictionContextArena,
  parent_id : Int,
  return_state_id : Int,
) -> Int {
  for node in arena.nodes {
    if parser_is_singleton_context(node.kind) &&
      node.parent_ids.length() == 1 &&
      node.parent_ids[0] == parent_id &&
      option_int_equals(node.return_state_id, Some(return_state_id)) {
      return node.context_id
    }
  }
  let context_id = arena.nodes.length()
  arena.nodes.push({
    context_id,
    kind: SingletonPredictionContext,
    return_state_id: Some(return_state_id),
    parent_ids: [parent_id],
  })
  context_id
}

///|

///|
/// Create a new prediction-context arena with the empty root context.
///
/// Example:
/// let arena = new_prediction_context_arena()
/// inspect(arena.empty_context_id(), content="0")
///
/// Notes:
/// - Context id `0` is reserved for the empty root context.
/// - The arena interns later singleton and merged contexts by structural identity.
pub fn new_prediction_context_arena() -> PredictionContextArena {
  {
    nodes: [
      {
        context_id: 0,
        kind: EmptyPredictionContext,
        return_state_id: None,
        parent_ids: [],
      },
    ],
  }
}

///|
/// Return the reserved empty root-context identifier.
///
/// Example:
/// let id = new_prediction_context_arena().empty_context_id()
/// inspect(id, content="0")
///
/// Notes:
/// - All top-level parser entries start from this context id.
pub fn PredictionContextArena::empty_context_id(
  _self : PredictionContextArena,
) -> Int {
  0
}

///|
/// Render one stable context path string for debugging and snapshotting.
///
/// Example:
/// let text = new_prediction_context_arena().render_context(0)
/// inspect(text, content="$")
///
/// Notes:
/// - The returned text is intended for config signatures and traces, not for user-facing diagnostics.
pub fn PredictionContextArena::render_context(
  self : PredictionContextArena,
  context_id : Int,
) -> String {
  parser_render_context(self, context_id)
}
