///|
/// One explicit parser semantic-predicate outcome provided by the host.
pub struct ParserPredicateBinding {
  text : String
  value : Bool
}

///|
/// One explicit parser action label provided by the host.
pub struct ParserActionBinding {
  text : String
  label : String
}

///|
/// Stable host hook surface used by the Phase 3 parser runtime.
pub struct ParserHostHooks {
  predicates : Array[ParserPredicateBinding]
  actions : Array[ParserActionBinding]
}

///|
fn parser_copy_predicate_bindings(
  values : Array[ParserPredicateBinding],
) -> Array[ParserPredicateBinding] {
  let copied : Array[ParserPredicateBinding] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn parser_copy_action_bindings(
  values : Array[ParserActionBinding],
) -> Array[ParserActionBinding] {
  let copied : Array[ParserActionBinding] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
/// Return an empty parser host-hook table.
///
/// Example:
/// let hooks = ParserHostHooks::empty()
/// inspect(hooks.predicates.length(), content="0")
///
/// Notes:
/// - Unbound predicates evaluate to `false`.
/// - Unbound actions fall back to their raw action text in parser traces.
pub fn ParserHostHooks::empty() -> ParserHostHooks {
  { predicates: [], actions: [] }
}

///|
/// Add or override one parser semantic-predicate binding.
///
/// Example:
/// let hooks = ParserHostHooks::empty().with_predicate("{ allow() }", true)
/// inspect(hooks.predicates.length(), content="1")
///
/// Notes:
/// - Later bindings for the same predicate text replace earlier ones.
pub fn ParserHostHooks::with_predicate(
  self : ParserHostHooks,
  text : String,
  value : Bool,
) -> ParserHostHooks {
  let predicates = parser_copy_predicate_bindings(self.predicates)
  for index = 0; index < predicates.length(); index = index + 1 {
    if predicates[index].text == text {
      predicates[index] = { text, value }
      return { predicates, actions: parser_copy_action_bindings(self.actions) }
    }
  }
  predicates.push({ text, value })
  { predicates, actions: parser_copy_action_bindings(self.actions) }
}

///|
/// Add or override one parser action label binding.
///
/// Example:
/// let hooks = ParserHostHooks::empty().with_action("{ mark() }", "mark")
/// inspect(hooks.actions.length(), content="1")
///
/// Notes:
/// - Later bindings for the same action text replace earlier ones.
pub fn ParserHostHooks::with_action(
  self : ParserHostHooks,
  text : String,
  label : String,
) -> ParserHostHooks {
  let actions = parser_copy_action_bindings(self.actions)
  for index = 0; index < actions.length(); index = index + 1 {
    if actions[index].text == text {
      actions[index] = { text, label }
      return {
        predicates: parser_copy_predicate_bindings(self.predicates),
        actions,
      }
    }
  }
  actions.push({ text, label })
  { predicates: parser_copy_predicate_bindings(self.predicates), actions }
}

///|
fn parser_predicate_binding_value(
  hooks : ParserHostHooks,
  text : String,
) -> Bool {
  for binding in hooks.predicates {
    if binding.text == text {
      return binding.value
    }
  }
  false
}

///|
fn parser_action_binding_label(
  hooks : ParserHostHooks,
  text : String,
) -> String {
  for binding in hooks.actions {
    if binding.text == text {
      return binding.label
    }
  }
  text
}
