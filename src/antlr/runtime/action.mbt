///|
/// One explicit semantic-predicate outcome provided by the host environment.
pub struct LexerPredicateBinding {
  text : String
  value : Bool
}

///|
/// One explicit action label provided by the host environment.
pub struct LexerActionBinding {
  text : String
  label : String
}

///|
/// Stable host hook surface used by the Phase 2 lexer runtime.
pub struct LexerHostHooks {
  predicates : Array[LexerPredicateBinding]
  actions : Array[LexerActionBinding]
}

///|
/// Return an empty host-hook table.
///
/// Example:
/// let hooks = LexerHostHooks::empty()
/// inspect(hooks.predicates.length(), content="0")
///
/// Notes:
/// - Unbound predicates evaluate to `false`.
/// - Unbound actions fall back to their raw action text in the action log.
pub fn LexerHostHooks::empty() -> LexerHostHooks {
  { predicates: [], actions: [] }
}

///|
/// Add or override one semantic-predicate binding.
///
/// Example:
/// let hooks = LexerHostHooks::empty().with_predicate("{ can() }", true)
/// inspect(hooks.predicates.length(), content="1")
///
/// Notes:
/// - Later bindings for the same predicate text replace earlier ones.
pub fn LexerHostHooks::with_predicate(
  self : LexerHostHooks,
  text : String,
  value : Bool,
) -> LexerHostHooks {
  let predicates = copy_predicate_bindings(self.predicates)
  for index = 0; index < predicates.length(); index = index + 1 {
    if predicates[index].text == text {
      predicates[index] = { text, value }
      return { predicates, actions: copy_action_bindings(self.actions) }
    }
  }
  predicates.push({ text, value })
  { predicates, actions: copy_action_bindings(self.actions) }
}

///|
/// Add or override one action label binding.
///
/// Example:
/// let hooks = LexerHostHooks::empty().with_action("{ mark() }", "mark")
/// inspect(hooks.actions.length(), content="1")
///
/// Notes:
/// - Later bindings for the same action text replace earlier ones.
pub fn LexerHostHooks::with_action(
  self : LexerHostHooks,
  text : String,
  label : String,
) -> LexerHostHooks {
  let actions = copy_action_bindings(self.actions)
  for index = 0; index < actions.length(); index = index + 1 {
    if actions[index].text == text {
      actions[index] = { text, label }
      return { predicates: copy_predicate_bindings(self.predicates), actions }
    }
  }
  actions.push({ text, label })
  { predicates: copy_predicate_bindings(self.predicates), actions }
}

///|
fn copy_predicate_bindings(
  values : Array[LexerPredicateBinding],
) -> Array[LexerPredicateBinding] {
  let copied : Array[LexerPredicateBinding] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn copy_action_bindings(
  values : Array[LexerActionBinding],
) -> Array[LexerActionBinding] {
  let copied : Array[LexerActionBinding] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn predicate_binding_value(hooks : LexerHostHooks, text : String) -> Bool {
  for binding in hooks.predicates {
    if binding.text == text {
      return binding.value
    }
  }
  false
}

///|
fn action_binding_label(hooks : LexerHostHooks, text : String) -> String {
  for binding in hooks.actions {
    if binding.text == text {
      return binding.label
    }
  }
  text
}
