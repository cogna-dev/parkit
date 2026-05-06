///|
/// One cached lexer-runtime entry derived from a state/input pair.
pub struct LexerDfaEntry {
  mode_name : String
  state_id : Int
  input_offset : Int
  matched_rule_name : String?
  matched_length : Int
  config_signature : String
}

///|
/// Early correctness-first lexer cache exposed for tests and debugging.
pub struct LexerDfa {
  entries : Array[LexerDfaEntry]
}

///|
/// Return an empty lexer cache structure.
///
/// Example:
/// let dfa = empty_lexer_dfa()
/// inspect(dfa.entries.length(), content="0")
///
/// Notes:
/// - This cache currently records runtime-observed state/input slices.
/// - It is a Phase 2 baseline and not yet a compressed ANTLR DFA wire format.
pub fn empty_lexer_dfa() -> LexerDfa {
  { entries: [] }
}

///|
fn copy_dfa_entries(values : Array[LexerDfaEntry]) -> Array[LexerDfaEntry] {
  let copied : Array[LexerDfaEntry] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn dfa_entry_exists(
  values : Array[LexerDfaEntry],
  wanted : LexerDfaEntry,
) -> Bool {
  for value in values {
    if value.mode_name == wanted.mode_name &&
      value.state_id == wanted.state_id &&
      value.input_offset == wanted.input_offset {
      return true
    }
  }
  false
}

///|
fn append_dfa_entries(
  dfa : LexerDfa,
  new_entries : Array[LexerDfaEntry],
) -> LexerDfa {
  let entries = copy_dfa_entries(dfa.entries)
  for entry in new_entries {
    if !dfa_entry_exists(entries, entry) {
      entries.push(entry)
    }
  }
  { entries, }
}
