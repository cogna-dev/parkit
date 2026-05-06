///|
fn tool_fixture_by_id(
  fixture_id : String,
) -> @antlr_fixture.UpstreamGrammarFixture {
  for fixture in @antlr_fixture.supported_frontend_fixtures() {
    if fixture.id == fixture_id {
      return fixture
    }
  }
  abort("expected tool fixture `" + fixture_id + "`")
}

///|
fn expect_tool_report(fixture_id : String) -> FrontendReport {
  let fixture = tool_fixture_by_id(fixture_id)
  let report = run_frontend_pipeline(fixture.source)
  if report.has_errors() {
    let diagnostics = report.all_diagnostics()
    if diagnostics.length() == 0 {
      abort("expected successful tool mirror frontend report")
    }
    abort(diagnostics[0].message)
  }
  match report.grammar {
    Some(grammar) =>
      if grammar.rules.length() != fixture.expected_rule_count {
        abort(
          "tool mirror parsed " +
          grammar.rules.length().to_string() +
          " rules instead of " +
          fixture.expected_rule_count.to_string(),
        )
      }
    None => abort("expected parsed grammar for tool fixture")
  }
  report
}

///|
fn find_tool_rule(grammar : GrammarSpec, rule_name : String) -> GrammarRuleSpec {
  for rule in grammar.rules {
    if rule.name == rule_name {
      return rule
    }
  }
  abort("expected tool mirror rule `" + rule_name + "`")
}

///|
fn tool_rule_has_skip_command(atn : GrammarAtn, rule_name : String) -> Bool {
  match atn.find_rule(rule_name) {
    Some(rule_graph) => {
      for state_id in rule_graph.state_ids {
        for transition in atn.outgoing_transitions(state_id) {
          match transition.kind {
            LexerCommandTransition(command) =>
              if command.name == "skip" {
                return true
              }
            _ => ()
          }
        }
      }
      false
    }
    None => abort("expected ATN rule `" + rule_name + "`")
  }
}

///|
fn element_has_fail_predicate(element : GrammarElement) -> Bool {
  match element.kind {
    PredicateElement(_, suffix) =>
      match suffix {
        Some(raw_suffix) => raw_suffix.contains("fail")
        None => false
      }
    GroupElement(alternatives) => {
      for alternative in alternatives {
        for child in alternative.elements {
          if element_has_fail_predicate(child) {
            return true
          }
        }
      }
      false
    }
    _ => false
  }
}

///|
fn rule_has_fail_predicate(rule : GrammarRuleSpec) -> Bool {
  for alternative in rule.alternatives {
    for element in alternative.elements {
      if element_has_fail_predicate(element) {
        return true
      }
    }
  }
  false
}

///|
fn atn_rule_has_predicate_transition(
  atn : GrammarAtn,
  rule_name : String,
) -> Bool {
  match atn.find_rule(rule_name) {
    Some(rule_graph) => {
      for state_id in rule_graph.state_ids {
        for transition in atn.outgoing_transitions(state_id) {
          match transition.kind {
            PredicateTransition(_, _) => return true
            _ => ()
          }
        }
      }
      false
    }
    None => abort("expected ATN rule `" + rule_name + "`")
  }
}

///|
fn find_tool_analysis(
  analyses : Array[LeftRecursionAnalysis],
  rule_name : String,
) -> LeftRecursionAnalysis {
  for analysis in analyses {
    if analysis.rule_name == rule_name {
      return analysis
    }
  }
  abort("expected tool mirror analysis for rule")
}

///|
fn has_tool_rewrite_plan(
  plans : Array[LeftRecursionRewritePlan],
  rule_name : String,
) -> Bool {
  for plan in plans {
    if plan.rule_name == rule_name {
      return true
    }
  }
  false
}

///|
test "tool mirror keeps position adjusting lexer members and skip commands" {
  let report = expect_tool_report("tool-position-adjusting-lexer")
  match report.grammar {
    Some(grammar) => {
      assert_eq(grammar.name, "PositionAdjustingLexer")
      assert_eq(grammar.named_actions.length(), 1)
      match grammar.named_actions[0].scope {
        Some(_) => abort("expected unscoped lexer members action")
        None => ()
      }
      assert_eq(grammar.named_actions[0].name, "members")
      assert_eq(
        grammar.named_actions[0].body.contains(
          "PositionAdjustingLexerATNSimulator",
        ),
        true,
      )
    }
    None => abort("expected parsed position-adjusting lexer grammar")
  }
  match report.grammar_atn {
    Some(atn) => {
      assert_eq(atn.find_token("TOKENS") is Some(_), true)
      assert_eq(atn.find_token("LABEL") is Some(_), true)
      assert_eq(tool_rule_has_skip_command(atn, "WS"), true)
      assert_eq(tool_rule_has_skip_command(atn, "NEWLINE"), true)
    }
    None => abort("expected ATN for position-adjusting lexer")
  }
}

///|
test "tool mirror keeps parser fail predicates in psl grammar" {
  let report = expect_tool_report("tool-psl")
  match report.grammar {
    Some(grammar) => {
      assert_eq(grammar.name, "Psl")
      assert_eq(grammar.named_actions.length(), 1)
      match grammar.named_actions[0].scope {
        Some(scope) => assert_eq(scope, "parser")
        None => abort("expected parser-scoped members action")
      }
      assert_eq(grammar.named_actions[0].name, "members")
      assert_eq(
        rule_has_fail_predicate(find_tool_rule(grammar, "floating_constant")),
        true,
      )
      assert_eq(
        rule_has_fail_predicate(find_tool_rule(grammar, "comma_number")),
        true,
      )
    }
    None => abort("expected parsed psl grammar")
  }
  match report.grammar_atn {
    Some(atn) => {
      assert_eq(
        atn_rule_has_predicate_transition(atn, "floating_constant"),
        true,
      )
      assert_eq(atn_rule_has_predicate_transition(atn, "comma_number"), true)
    }
    None => abort("expected ATN for psl grammar")
  }
}

///|
test "tool mirror distinguishes java lr rewrite from precedence ladder java" {
  let java_lr_report = expect_tool_report("tool-java-lr")
  let java_report = expect_tool_report("tool-java")
  let java_lr_analysis = find_tool_analysis(
    java_lr_report.left_recursion_analyses,
    "expression",
  )
  assert_eq(java_lr_analysis.has_immediate_left_recursion, true)
  assert_eq(
    has_tool_rewrite_plan(
      java_lr_report.left_recursion_rewrite_plans,
      "expression",
    ),
    true,
  )
  match java_lr_report.grammar_atn {
    Some(atn) => {
      assert_eq(atn.rules.length() > 200, true)
      match atn.find_rule("expression") {
        Some(rule_graph) => assert_eq(rule_graph.rewritten, true)
        None => abort("expected java lr expression rule graph")
      }
    }
    None => abort("expected ATN for java lr grammar")
  }
  let java_analysis = find_tool_analysis(
    java_report.left_recursion_analyses,
    "expression",
  )
  assert_eq(java_analysis.has_immediate_left_recursion, false)
  assert_eq(
    has_tool_rewrite_plan(
      java_report.left_recursion_rewrite_plans,
      "expression",
    ),
    false,
  )
  match java_report.grammar_atn {
    Some(atn) => {
      assert_eq(atn.rules.length() > 200, true)
      match atn.find_rule("expression") {
        Some(rule_graph) => assert_eq(rule_graph.rewritten, false)
        None => abort("expected java expression rule graph")
      }
    }
    None => abort("expected ATN for java grammar")
  }
}
