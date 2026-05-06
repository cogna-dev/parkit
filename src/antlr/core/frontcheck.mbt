///|
fn find_frontend_analysis(
  analyses : Array[LeftRecursionAnalysis],
  rule_name : String,
) -> LeftRecursionAnalysis {
  for analysis in analyses {
    if analysis.rule_name == rule_name {
      return analysis
    }
  }
  abort("expected frontend analysis for rule")
}

///|
fn find_frontend_rewrite_plan(
  plans : Array[LeftRecursionRewritePlan],
  rule_name : String,
) -> LeftRecursionRewritePlan {
  for plan in plans {
    if plan.rule_name == rule_name {
      return plan
    }
  }
  abort("expected frontend rewrite plan for rule")
}

///|
test "frontend pipeline aggregates parse and semantic stages" {
  let report = run_frontend_pipeline(
    "grammar Hello;\n\nimport HelloBase;\n\nr : 'hello' ID ;\nID : [a-z]+ ;\nWS : [ \\r\\t\\n]+ -> skip ;\n",
  )
  assert_eq(report.has_errors(), false)
  assert_eq(report.parse_diagnostics.length(), 0)
  assert_eq(report.semantic_diagnostics.length(), 0)
  match report.semantic_model {
    Some(model) => {
      assert_eq(model.rules.length(), 3)
      match model.start_rule() {
        Some(rule) => assert_eq(rule.name, "r")
        None => abort("expected semantic start rule")
      }
    }
    None => abort("expected semantic model")
  }
  assert_eq(report.left_recursion_analyses.length(), 1)
  assert_eq(report.left_recursion_rewrite_plans.length(), 0)
  assert_eq(report.left_recursion_materialized_rules.length(), 0)
  match report.left_recursion_rewritten_grammar {
    Some(_) => abort("expected no rewritten grammar without left recursion")
    None => ()
  }
  match report.normalized_grammar {
    Some(normalized) => assert_eq(normalized.rules.length(), 3)
    None => abort("expected normalized grammar")
  }
  match report.grammar_atn {
    Some(grammar_atn) => {
      assert_eq(grammar_atn.rules.length(), 3)
      assert_eq(grammar_atn.public_rules.length(), 3)
      assert_eq(grammar_atn.public_tokens.length(), 3)
      assert_eq(grammar_atn.public_channels.length(), 2)
      assert_eq(grammar_atn.public_modes.length(), 1)
    }
    None => abort("expected grammar ATN for successful frontend run")
  }
  match report.grammar {
    Some(grammar) => assert_eq(grammar.name, "Hello")
    None => abort("expected parsed grammar")
  }
}

///|
test "frontend pipeline exposes left recursion analyses" {
  let report = run_frontend_pipeline(
    "grammar Expr;\n\nexpr\n  : expr '*' expr # Mul\n  | expr '++' # PostInc\n  | '-' expr # Neg\n  | ID # Atom\n  ;\n\nterm : expr ;\nID : [a-z]+ ;\nWS : [ \\r\\t\\n]+ -> skip ;\n",
  )
  assert_eq(report.has_errors(), false)
  let analysis = find_frontend_analysis(report.left_recursion_analyses, "expr")
  let plan = find_frontend_rewrite_plan(
    report.left_recursion_rewrite_plans,
    "expr",
  )
  assert_eq(analysis.has_immediate_left_recursion, true)
  assert_eq(analysis.binary_alternatives.length(), 1)
  assert_eq(analysis.suffix_alternatives.length(), 1)
  assert_eq(analysis.prefix_alternatives.length(), 1)
  assert_eq(plan.operator_alternatives.length(), 2)
  assert_eq(plan.primary_alternatives.length(), 2)
  assert_eq(report.left_recursion_materialized_rules.length(), 1)
  assert_eq(report.left_recursion_materialized_rules[0].rule_name, "expr")
  assert_eq(report.left_recursion_materialized_rules[0].diagnostics.length(), 0)
  match report.left_recursion_materialized_rules[0].rewritten_rule {
    Some(rule) =>
      match rule.signature {
        Some(signature) => assert_eq(signature, "[p]")
        None => abort("expected synthetic precedence signature")
      }
    None => abort("expected materialized rewritten rule")
  }
  match report.left_recursion_rewritten_grammar {
    Some(rewritten_grammar) => {
      assert_eq(rewritten_grammar.rules.length(), 4)
      match rewritten_grammar.rules[0].signature {
        Some(signature) => assert_eq(signature, "[p]")
        None => abort("expected rewritten expr signature")
      }
      match rewritten_grammar.rules[1].alternatives[0].elements[0].kind {
        RuleReferenceElement(rule_ref) =>
          match rule_ref.args {
            Some(args) => assert_eq(args, "[0]")
            None => abort("expected precedence seed on external expr reference")
          }
        _ => abort("expected rewritten term rule to reference expr")
      }
    }
    None => abort("expected rewritten grammar")
  }
  match report.grammar_atn {
    Some(grammar_atn) => {
      assert_eq(grammar_atn.rules.length(), 4)
      assert_eq(grammar_atn.public_rules.length(), 4)
      assert_eq(grammar_atn.public_alternatives.length() >= 5, true)
      match grammar_atn.find_rule("expr") {
        Some(rule_graph) => {
          let outgoing = grammar_atn.outgoing_transitions(
            rule_graph.start_state_id,
          )
          assert_eq(outgoing.length() > 0, true)
          assert_eq(rule_graph.rewritten, true)
        }
        None => abort("expected expr rule graph")
      }
    }
    None => abort("expected ATN for rewritten grammar")
  }
  match report.normalized_grammar {
    Some(normalized) =>
      match normalized.find_rule("expr") {
        Some(rule) => assert_eq(rule.rewritten, true)
        None => abort("expected normalized expr rule")
      }
    None => abort("expected normalized grammar")
  }
}

///|
test "frontend pipeline stops later stages on parse failure" {
  let report = run_frontend_pipeline("grammar Broken\nrule : ID ;\n")
  assert_eq(report.has_errors(), true)
  assert_eq(report.parse_diagnostics.length(), 1)
  assert_eq(report.semantic_diagnostics.length(), 0)
  assert_eq(report.left_recursion_analyses.length(), 0)
  assert_eq(report.left_recursion_rewrite_plans.length(), 0)
  assert_eq(report.left_recursion_materialized_rules.length(), 0)
  match report.left_recursion_rewritten_grammar {
    Some(_) => abort("expected no rewritten grammar on parse failure")
    None => ()
  }
  match report.grammar_atn {
    Some(_) => abort("expected no ATN on parse failure")
    None => ()
  }
  match report.grammar {
    Some(_) => abort("expected parse failure")
    None => ()
  }
}

///|
test "frontend report includes materialization diagnostics in all_diagnostics" {
  let report = make_frontend_report(
    None,
    [],
    [],
    None,
    [],
    [],
    [
      make_left_recursion_materialized_rule(
        "expr",
        "expr[p]\n  : ID\n  ;",
        None,
        [
          Diagnostic::error(
            "synthetic rewrite failed",
            SourceSpan::point(SourcePos::new(0, 0, 0)),
          ),
        ],
      ),
    ],
    None,
    None,
    None,
  )
  assert_eq(report.all_diagnostics().length(), 1)
  assert_eq(report.has_errors(), true)
}
