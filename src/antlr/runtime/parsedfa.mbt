///|
/// One cached parser-decision entry derived from a decision/input pair.
pub struct ParserDfaEntry {
  decision_id : Int
  input_offset : Int
  lookahead_token_name : String
  chosen_alternative : Int?
  ambiguous_alternatives : Array[Int]
  used_full_context : Bool
  config_signature : String
}

///|
/// Early correctness-first parser cache exposed for tests and debugging.
pub struct ParserDfa {
  entries : Array[ParserDfaEntry]
}

///|
fn parser_copy_dfa_alt_values(values : Array[Int]) -> Array[Int] {
  let copied : Array[Int] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn parser_copy_dfa_entries(
  values : Array[ParserDfaEntry],
) -> Array[ParserDfaEntry] {
  let copied : Array[ParserDfaEntry] = []
  for value in values {
    copied.push({
      decision_id: value.decision_id,
      input_offset: value.input_offset,
      lookahead_token_name: value.lookahead_token_name,
      chosen_alternative: value.chosen_alternative,
      ambiguous_alternatives: parser_copy_dfa_alt_values(
        value.ambiguous_alternatives,
      ),
      used_full_context: value.used_full_context,
      config_signature: value.config_signature,
    })
  }
  copied
}

///|
fn parser_dfa_entry_exists(
  values : Array[ParserDfaEntry],
  wanted : ParserDfaEntry,
) -> Bool {
  for value in values {
    if value.decision_id == wanted.decision_id &&
      value.input_offset == wanted.input_offset {
      return true
    }
  }
  false
}

///|
fn append_parser_dfa_entries(
  dfa : ParserDfa,
  new_entries : Array[ParserDfaEntry],
) -> ParserDfa {
  let entries = parser_copy_dfa_entries(dfa.entries)
  for entry in new_entries {
    if !parser_dfa_entry_exists(entries, entry) {
      entries.push(entry)
    }
  }
  { entries, }
}

///|
/// Return an empty parser decision-cache structure.
///
/// Example:
/// let dfa = empty_parser_dfa()
/// inspect(dfa.entries.length(), content="0")
///
/// Notes:
/// - This cache currently records runtime-observed decision/input slices.
/// - It is a Phase 3 baseline and not yet ANTLR's full adaptive DFA wire format.
pub fn empty_parser_dfa() -> ParserDfa {
  { entries: [] }
}
