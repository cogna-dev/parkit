///|
fn expect_parsed_for_atn(source : String) -> GrammarSpec {
  let outcome = parse_grammar(source)
  if outcome.diagnostics.length() != 0 {
    abort(outcome.diagnostics[0].message)
  }
  match outcome.grammar {
    Some(grammar) => grammar
    None => abort("expected parse success")
  }
}

///|
fn expect_rule_graph(atn : GrammarAtn, rule_name : String) -> AtnRuleGraph {
  match atn.find_rule(rule_name) {
    Some(rule_graph) => rule_graph
    None => abort("expected rule graph")
  }
}

///|
fn count_rule_states_by_kind(
  atn : GrammarAtn,
  rule_graph : AtnRuleGraph,
  kind : AtnStateKind,
) -> Int {
  let mut count = 0
  for state_id in rule_graph.state_ids {
    match atn.state(state_id) {
      Some(state) =>
        if atn_state_kind_name(state.kind) == atn_state_kind_name(kind) {
          count = count + 1
        }
      None => abort("expected ATN state")
    }
  }
  count
}

///|
fn rule_transitions(
  atn : GrammarAtn,
  rule_graph : AtnRuleGraph,
) -> Array[AtnTransition] {
  let transitions : Array[AtnTransition] = []
  for state_id in rule_graph.state_ids {
    for transition in atn.outgoing_transitions(state_id) {
      transitions.push(transition)
    }
  }
  transitions
}

///|
fn find_atn_golden_snapshot_fixture(
  fixture_id : String,
) -> @antlr_fixture.AtnGoldenSnapshotFixture {
  for fixture in @antlr_fixture.representative_atn_snapshots() {
    if fixture.id == fixture_id {
      return fixture
    }
  }
  abort("expected ATN golden snapshot fixture `" + fixture_id + "`")
}

///|
fn serialized_atn_for_fixture(fixture_id : String) -> String {
  let fixture = find_atn_golden_snapshot_fixture(fixture_id)
  serialize_grammar_atn(
    build_grammar_atn(expect_parsed_for_atn(fixture.source)),
  )
}

///|
fn assert_atn_golden_snapshot(fixture_id : String) -> Unit {
  let fixture = find_atn_golden_snapshot_fixture(fixture_id)
  let actual = serialized_atn_for_fixture(fixture_id)
  if actual != fixture.expected_serialized_atn {
    println(actual)
    abort("ATN golden snapshot mismatch for `" + fixture_id + "`")
  }
}

///|
test "build atn preserves basic literal and token edges" {
  let grammar = expect_parsed_for_atn(
    "grammar Hello;\n\nr : 'hello' ID ;\nID : [a-z]+ ;\nWS : [ \\r\\t\\n]+ -> skip ;\n",
  )
  let atn = build_grammar_atn(grammar)
  let rule_graph = expect_rule_graph(atn, "r")
  assert_eq(count_rule_states_by_kind(atn, rule_graph, RuleStartState), 1)
  assert_eq(count_rule_states_by_kind(atn, rule_graph, RuleStopState), 1)
  let transitions = rule_transitions(atn, rule_graph)
  let mut saw_literal = false
  let mut saw_token_ref = false
  for transition in transitions {
    match transition.kind {
      StringLiteralTransition(text) =>
        if text == "'hello'" {
          saw_literal = true
        }
      TokenReferenceTransition(name) => if name == "ID" { saw_token_ref = true }
      _ => ()
    }
  }
  assert_eq(saw_literal, true)
  assert_eq(saw_token_ref, true)
}

///|
test "build atn models groups and optional structure" {
  let grammar = expect_parsed_for_atn(
    "parser grammar Demo;\n\nrule : ID ('(' value | '[' value ']')? ;\nvalue : ID ;\n",
  )
  let atn = build_grammar_atn(grammar)
  let rule_graph = expect_rule_graph(atn, "rule")
  assert_eq(
    count_rule_states_by_kind(atn, rule_graph, BlockStartState) >= 2,
    true,
  )
  assert_eq(
    count_rule_states_by_kind(atn, rule_graph, BlockEndState) >= 2,
    true,
  )
  let mut saw_rule_ref = false
  for transition in rule_transitions(atn, rule_graph) {
    match transition.kind {
      RuleReferenceTransition(rule_call) =>
        if rule_call.rule_ref.name == "value" {
          saw_rule_ref = true
        }
      _ => ()
    }
  }
  assert_eq(saw_rule_ref, true)
}

///|
test "build atn preserves nongreedy loops, predicates, and lexer commands" {
  let grammar = expect_parsed_for_atn(
    "lexer grammar Modes;\n\nchannels { COMMENTS }\n\nOPEN : '/*' -> pushMode(COMMENT_MODE), skip ;\nmode COMMENT_MODE;\nCOMMENT : { can() }? .*? -> channel(COMMENTS) ;\n",
  )
  let atn = build_grammar_atn(grammar)
  let open_rule = expect_rule_graph(atn, "OPEN")
  let comment_rule = expect_rule_graph(atn, "COMMENT")
  let mut saw_push_mode = false
  let mut saw_skip = false
  for transition in rule_transitions(atn, open_rule) {
    match transition.kind {
      LexerCommandTransition(command) => {
        if command.name == "pushMode" {
          match command.args {
            Some(args) => if args == "(COMMENT_MODE)" { saw_push_mode = true }
            None => ()
          }
        }
        if command.name == "skip" {
          saw_skip = true
        }
      }
      _ => ()
    }
  }
  assert_eq(saw_push_mode, true)
  assert_eq(saw_skip, true)
  let mut saw_predicate = false
  let mut saw_channel = false
  let mut saw_nongreedy_loop = false
  for state_id in comment_rule.state_ids {
    match atn.state(state_id) {
      Some(state) =>
        match state.kind {
          StarBlockStartState | LoopBackState =>
            if state.greedy == false {
              saw_nongreedy_loop = true
            }
          _ => ()
        }
      None => abort("expected comment state")
    }
  }
  for transition in rule_transitions(atn, comment_rule) {
    match transition.kind {
      PredicateTransition(text, _) =>
        if text == "{ can() }" {
          saw_predicate = true
        }
      LexerCommandTransition(command) =>
        if command.name == "channel" {
          saw_channel = true
        }
      _ => ()
    }
  }
  assert_eq(saw_predicate, true)
  assert_eq(saw_channel, true)
  assert_eq(saw_nongreedy_loop, true)
  assert_eq(atn.mode_starts.length(), 2)
  assert_eq(atn.decisions.length() > 0, true)
}

///|
test "serialize and deserialize atn preserves public metadata" {
  let grammar = expect_parsed_for_atn(
    "grammar Expr;\n\nexpr\n  : expr '+' expr # Add\n  | INT # Atom\n  ;\n\nINT : [0-9]+ ;\nWS : [ \\r\\t\\n]+ -> skip ;\n",
  )
  let atn = build_grammar_atn(grammar)
  let serialized = serialize_grammar_atn(atn)
  let roundtrip = match deserialize_grammar_atn(serialized) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  assert_eq(roundtrip.grammar_name, atn.grammar_name)
  assert_eq(roundtrip.grammar_fingerprint, atn.grammar_fingerprint)
  assert_eq(roundtrip.states.length(), atn.states.length())
  assert_eq(roundtrip.transitions.length(), atn.transitions.length())
  assert_eq(roundtrip.rules.length(), atn.rules.length())
  assert_eq(roundtrip.decisions.length(), atn.decisions.length())
  assert_eq(roundtrip.public_rules.length(), atn.public_rules.length())
  assert_eq(
    roundtrip.public_alternatives.length(),
    atn.public_alternatives.length(),
  )
  assert_eq(roundtrip.public_slots.length(), atn.public_slots.length())
  assert_eq(roundtrip.public_tokens.length(), atn.public_tokens.length())
  assert_eq(roundtrip.public_channels.length(), atn.public_channels.length())
  assert_eq(roundtrip.public_modes.length(), atn.public_modes.length())
  match roundtrip.find_rule("expr") {
    Some(rule_graph) => assert_eq(rule_graph.rewritten, true)
    None => abort("expected round-tripped expr rule graph")
  }
}

///|
test "serialized atn matches hello golden snapshot" {
  assert_atn_golden_snapshot("hello-basic")
}

///|
test "serialized atn matches expr golden snapshot" {
  assert_atn_golden_snapshot("expr-left-recursive")
}

///|
test "serialized atn matches lexer modes golden snapshot" {
  assert_atn_golden_snapshot("lexer-modes")
}
