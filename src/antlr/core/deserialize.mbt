///|
fn decode_rule_kind_field(raw : String) -> Result[GrammarRuleKind, String] {
  let value = match decode_string_field(raw) {
    Ok(decoded) => decoded
    Err(error) => return Err(error)
  }
  if value == "parser" {
    Ok(ParserRule)
  } else if value == "lexer" {
    Ok(LexerRule)
  } else {
    Err("unknown rule kind")
  }
}

///|
fn decode_grammar_kind_field(raw : String) -> Result[GrammarKind, String] {
  let value = match decode_string_field(raw) {
    Ok(decoded) => decoded
    Err(error) => return Err(error)
  }
  if value == "combined" {
    Ok(Combined)
  } else if value == "lexer" {
    Ok(Lexer)
  } else if value == "parser" {
    Ok(Parser)
  } else {
    Err("unknown grammar kind")
  }
}

///|
fn decode_state_kind_field(raw : String) -> Result[AtnStateKind, String] {
  let value = match decode_string_field(raw) {
    Ok(decoded) => decoded
    Err(error) => return Err(error)
  }
  if value == "rule-start" {
    Ok(RuleStartState)
  } else if value == "rule-stop" {
    Ok(RuleStopState)
  } else if value == "basic" {
    Ok(BasicState)
  } else if value == "block-start" {
    Ok(BlockStartState)
  } else if value == "block-end" {
    Ok(BlockEndState)
  } else if value == "plus-block-start" {
    Ok(PlusBlockStartState)
  } else if value == "star-block-start" {
    Ok(StarBlockStartState)
  } else if value == "loop-entry" {
    Ok(LoopEntryState)
  } else if value == "loop-back" {
    Ok(LoopBackState)
  } else if value == "loop-end" {
    Ok(LoopEndState)
  } else if value == "mode-start" {
    Ok(ModeStartState)
  } else if value == "rule-call" {
    Ok(RuleCallState)
  } else {
    Err("unknown state kind")
  }
}

///|
fn decode_decision_kind_field(raw : String) -> Result[AtnDecisionKind, String] {
  let value = match decode_string_field(raw) {
    Ok(decoded) => decoded
    Err(error) => return Err(error)
  }
  if value == "block" {
    Ok(BlockDecision)
  } else if value == "optional" {
    Ok(OptionalDecision)
  } else if value == "loop-entry" {
    Ok(LoopEntryDecision)
  } else if value == "loop-back" {
    Ok(LoopBackDecision)
  } else if value == "mode-start" {
    Ok(ModeStartDecision)
  } else {
    Err("unknown decision kind")
  }
}

///|
fn decode_suffix_kind_field(raw : String) -> Result[EbnfSuffixKind, String] {
  if raw == "optional" {
    Ok(OptionalSuffix)
  } else if raw == "zero-or-more" {
    Ok(ZeroOrMoreSuffix)
  } else if raw == "one-or-more" {
    Ok(OneOrMoreSuffix)
  } else {
    Err("unknown suffix kind")
  }
}

///|
fn require_field_count(
  fields : Array[String],
  count : Int,
  tag : String,
) -> Result[Unit, String] {
  if fields.length() == count {
    Ok(())
  } else {
    Err("invalid field count for `" + tag + "`")
  }
}

///|
/// Deserialize the stable Phase 1 ATN text format back into a `GrammarAtn` value.
///
/// Example:
/// let roundtrip = deserialize_grammar_atn(serialized)
/// inspect(roundtrip is Ok(_), content="true")
///
/// Notes:
/// - The input must come from `serialize_grammar_atn` version 1.
/// - Malformed lines return `Err(message)` instead of aborting.
pub fn deserialize_grammar_atn(
  serialized : String,
) -> Result[GrammarAtn, String] {
  let lines = serialized.split("\n").map(line => line.to_string()).to_array()
  if lines.length() < 2 {
    return Err("serialized ATN is missing header")
  }
  let header = split_atn_fields(lines[0])
  match require_field_count(header, 2, "ATN") {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  if header[0] != "ATN" {
    return Err("invalid ATN header")
  }
  let version = match parse_decimal_int(header[1]) {
    Some(value) => value
    None => return Err("invalid ATN version")
  }
  if version != atn_serialization_version {
    return Err("unsupported ATN version")
  }

  let grammar_fields = split_atn_fields(lines[1])
  match require_field_count(grammar_fields, 5, "grammar") {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  if grammar_fields[0] != "grammar" {
    return Err("serialized ATN is missing grammar line")
  }
  let grammar_name = match decode_string_field(grammar_fields[1]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let grammar_kind = match decode_grammar_kind_field(grammar_fields[2]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let grammar_fingerprint = match decode_string_field(grammar_fields[3]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let start_rule_id = match decode_option_int_field(grammar_fields[4]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }

  let public_rules : Array[GrammarRuleSymbol] = []
  let public_alternatives : Array[GrammarAlternativeSymbol] = []
  let public_slots : Array[GrammarSlotSymbol] = []
  let public_tokens : Array[GrammarTokenSymbol] = []
  let public_channels : Array[GrammarChannelSymbol] = []
  let public_modes : Array[GrammarModeSymbol] = []
  let states : Array[AtnState] = []
  let transitions : Array[AtnTransition] = []
  let rules : Array[AtnRuleGraph] = []
  let decisions : Array[AtnDecision] = []
  let mode_starts : Array[AtnModeStart] = []

  for index = 2; index < lines.length(); index = index + 1 {
    let line = lines[index]
    if line == "" {
      continue
    }
    let fields = split_atn_fields(line)
    let tag = fields[0]
    if tag == "public-rule" {
      match require_field_count(fields, 9, tag) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      public_rules.push({
        rule_id: match parse_decimal_int(fields[1]) {
          Some(value) => value
          None => return Err("invalid public-rule id")
        },
        name: match decode_string_field(fields[2]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        kind: match decode_rule_kind_field(fields[3]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        is_fragment: match decode_bool_field(fields[4]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        signature: match decode_option_string_field(fields[5]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        mode: match decode_option_string_field(fields[6]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        declaring_grammar: match decode_string_field(fields[7]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        span: match decode_span_field(fields[8]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      })
    } else if tag == "public-alt" {
      match require_field_count(fields, 5, tag) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      public_alternatives.push({
        rule_id: match parse_decimal_int(fields[1]) {
          Some(value) => value
          None => return Err("invalid public-alt rule id")
        },
        alternative_index: match parse_decimal_int(fields[2]) {
          Some(value) => value
          None => return Err("invalid public-alt index")
        },
        label: match decode_option_string_field(fields[3]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        span: match decode_span_field(fields[4]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      })
    } else if tag == "public-slot" {
      match require_field_count(fields, 13, tag) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      let label_name = match decode_option_string_field(fields[5]) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let label_kind = match decode_option_string_field(fields[6]) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let suffix_kind = match decode_option_string_field(fields[9]) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let suffix_greedy = match decode_option_string_field(fields[10]) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      public_slots.push({
        rule_id: match parse_decimal_int(fields[1]) {
          Some(value) => value
          None => return Err("invalid public-slot rule id")
        },
        alternative_index: match parse_decimal_int(fields[2]) {
          Some(value) => value
          None => return Err("invalid public-slot alternative index")
        },
        slot_id: match parse_decimal_int(fields[3]) {
          Some(value) => value
          None => return Err("invalid public-slot slot id")
        },
        element_index: match parse_decimal_int(fields[4]) {
          Some(value) => value
          None => return Err("invalid public-slot element index")
        },
        label: match (label_name, label_kind) {
          (Some(name), Some(kind)) => Some({ name, is_list: kind == "list" })
          _ => None
        },
        source_kind: match
          decode_slot_source_kind_field(
            match decode_string_field(fields[7]) {
              Ok(value) => value
              Err(error) => return Err(error)
            },
            fields[8],
          ) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        suffix: match suffix_kind {
          Some(kind_name) =>
            Some({
              kind: match decode_suffix_kind_field(kind_name) {
                Ok(value) => value
                Err(error) => return Err(error)
              },
              greedy: match suffix_greedy {
                Some(value) => value == "greedy"
                None => true
              },
            })
          None => None
        },
        negated: match decode_bool_field(fields[11]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        span: match decode_span_field(fields[12]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      })
    } else if tag == "public-token" {
      match require_field_count(fields, 5, tag) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      public_tokens.push({
        token_id: match parse_decimal_int(fields[1]) {
          Some(value) => value
          None => return Err("invalid public-token id")
        },
        name: match decode_string_field(fields[2]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        literal_name: match decode_option_string_field(fields[3]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        implicit: match decode_bool_field(fields[4]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      })
    } else if tag == "public-channel" {
      match require_field_count(fields, 3, tag) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      public_channels.push({
        channel_id: match parse_decimal_int(fields[1]) {
          Some(value) => value
          None => return Err("invalid public-channel id")
        },
        name: match decode_string_field(fields[2]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      })
    } else if tag == "public-mode" {
      match require_field_count(fields, 3, tag) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      public_modes.push({
        mode_id: match parse_decimal_int(fields[1]) {
          Some(value) => value
          None => return Err("invalid public-mode id")
        },
        name: match decode_string_field(fields[2]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      })
    } else if tag == "state" {
      match require_field_count(fields, 9, tag) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      states.push({
        id: match parse_decimal_int(fields[1]) {
          Some(value) => value
          None => return Err("invalid state id")
        },
        rule_name: match decode_option_string_field(fields[2]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        rule_id: match decode_option_int_field(fields[3]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        mode: match decode_option_string_field(fields[4]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        kind: match decode_state_kind_field(fields[5]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        greedy: match decode_bool_field(fields[6]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        decision_id: match decode_option_int_field(fields[7]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        origin: match decode_origin_field(fields[8]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      })
    } else if tag == "transition" {
      match require_field_count(fields, 12, tag) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      let kind_name = match decode_string_field(fields[3]) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      transitions.push({
        source_state_id: match parse_decimal_int(fields[1]) {
          Some(value) => value
          None => return Err("invalid transition source state")
        },
        target_state_id: match parse_decimal_int(fields[2]) {
          Some(value) => value
          None => return Err("invalid transition target state")
        },
        kind: match
          decode_transition_payload(
            kind_name,
            fields[6],
            fields[7],
            fields[8],
            fields[9],
            fields[10],
          ) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        negated: match decode_bool_field(fields[4]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        order: match parse_decimal_int(fields[5]) {
          Some(value) => value
          None => return Err("invalid transition order")
        },
        origin: match decode_origin_field(fields[11]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      })
    } else if tag == "rule-graph" {
      match require_field_count(fields, 11, tag) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      rules.push({
        rule_id: match parse_decimal_int(fields[1]) {
          Some(value) => value
          None => return Err("invalid rule-graph rule id")
        },
        rule_name: match decode_string_field(fields[2]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        kind: match decode_rule_kind_field(fields[3]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        mode: match decode_option_string_field(fields[4]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        signature: match decode_option_string_field(fields[5]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        start_state_id: match parse_decimal_int(fields[6]) {
          Some(value) => value
          None => return Err("invalid rule-graph start state")
        },
        stop_state_id: match parse_decimal_int(fields[7]) {
          Some(value) => value
          None => return Err("invalid rule-graph stop state")
        },
        state_ids: match decode_int_array_field(fields[8]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        decision_ids: match decode_int_array_field(fields[9]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        rewritten: match decode_bool_field(fields[10]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      })
    } else if tag == "decision" {
      match require_field_count(fields, 7, tag) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      let public_alternatives = match decode_alt_origin_array_field(fields[6]) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      decisions.push({
        decision_id: match parse_decimal_int(fields[1]) {
          Some(value) => value
          None => return Err("invalid decision id")
        },
        rule_name: match decode_option_string_field(fields[2]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        rule_id: match decode_option_int_field(fields[3]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        state_id: match parse_decimal_int(fields[4]) {
          Some(value) => value
          None => return Err("invalid decision state id")
        },
        kind: match decode_decision_kind_field(fields[5]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        alternative_count: public_alternatives.length(),
        public_alternatives,
      })
    } else if tag == "mode-start" {
      match require_field_count(fields, 4, tag) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      mode_starts.push({
        mode_name: match decode_string_field(fields[1]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
        state_id: match parse_decimal_int(fields[2]) {
          Some(value) => value
          None => return Err("invalid mode-start state id")
        },
        rule_ids: match decode_int_array_field(fields[3]) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      })
    } else {
      return Err("unknown serialized ATN tag `" + tag + "`")
    }
  }

  Ok({
    grammar_name,
    grammar_kind,
    grammar_fingerprint,
    start_rule_id,
    states,
    transitions,
    rules,
    decisions,
    mode_starts,
    public_rules,
    public_alternatives,
    public_slots,
    public_tokens,
    public_channels,
    public_modes,
  })
}
