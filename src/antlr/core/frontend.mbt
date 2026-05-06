///|
/// Aggregated output of the current grammar frontend pipeline.
pub struct FrontendReport {
  grammar : GrammarSpec?
  parse_diagnostics : Array[Diagnostic]
  semantic_diagnostics : Array[Diagnostic]
  semantic_model : SemanticModel?
  left_recursion_analyses : Array[LeftRecursionAnalysis]
  left_recursion_rewrite_plans : Array[LeftRecursionRewritePlan]
  left_recursion_materialized_rules : Array[LeftRecursionMaterializedRule]
  left_recursion_rewritten_grammar : GrammarSpec?
  normalized_grammar : NormalizedGrammar?
  grammar_atn : GrammarAtn?
}

///|
/// Assemble one frontend report from parse, semantic, rewrite, normalization, and ATN stages.
///
/// Example:
/// let report = make_frontend_report(None, [], [], None, [], [], [], None, None, None)
/// inspect(report.grammar_atn is None, content="true")
///
/// Notes:
/// - `semantic_model` and `normalized_grammar` are only present when semantic analysis succeeds.
/// - `left_recursion_rewritten_grammar` remains a debug artifact and is not the source of truth for public ATN metadata.
pub fn make_frontend_report(
  grammar : GrammarSpec?,
  parse_diagnostics : Array[Diagnostic],
  semantic_diagnostics : Array[Diagnostic],
  semantic_model : SemanticModel?,
  left_recursion_analyses : Array[LeftRecursionAnalysis],
  left_recursion_rewrite_plans : Array[LeftRecursionRewritePlan],
  left_recursion_materialized_rules : Array[LeftRecursionMaterializedRule],
  left_recursion_rewritten_grammar : GrammarSpec?,
  normalized_grammar : NormalizedGrammar?,
  grammar_atn : GrammarAtn?,
) -> FrontendReport {
  {
    grammar,
    parse_diagnostics,
    semantic_diagnostics,
    semantic_model,
    left_recursion_analyses,
    left_recursion_rewrite_plans,
    left_recursion_materialized_rules,
    left_recursion_rewritten_grammar,
    normalized_grammar,
    grammar_atn,
  }
}

///|
pub fn make_left_recursion_materialized_rule(
  rule_name : String,
  synthetic_source : String,
  rewritten_rule : GrammarRuleSpec?,
  diagnostics : Array[Diagnostic],
) -> LeftRecursionMaterializedRule {
  { rule_name, synthetic_source, rewritten_rule, diagnostics }
}

///|
pub fn FrontendReport::all_diagnostics(
  self : FrontendReport,
) -> Array[Diagnostic] {
  let diagnostics : Array[Diagnostic] = []
  for diagnostic in self.parse_diagnostics {
    diagnostics.push(diagnostic)
  }
  for diagnostic in self.semantic_diagnostics {
    diagnostics.push(diagnostic)
  }
  for materialized_rule in self.left_recursion_materialized_rules {
    for diagnostic in materialized_rule.diagnostics {
      diagnostics.push(diagnostic)
    }
  }
  diagnostics
}

///|
pub fn FrontendReport::has_errors(self : FrontendReport) -> Bool {
  self.all_diagnostics().length() > 0
}

///|
/// Run the current frontend pipeline all the way through normalization and ATN lowering.
///
/// Example:
/// let report = run_frontend_pipeline("grammar Hello; r : 'x' ;")
/// inspect(report.grammar_atn is Some(_), content="true")
///
/// Notes:
/// - Public ATN metadata always comes from the original grammar via normalization, not from the rewritten debug grammar.
/// - Left-recursion materialization is still exposed separately for inspection and regression tests.
pub fn run_frontend_pipeline(source : String) -> FrontendReport {
  let parse_outcome = parse_grammar(source)
  match parse_outcome.grammar {
    Some(grammar) => {
      let semantic_summary = analyze_grammar(grammar)
      let rewrite_plans = plan_left_recursive_rewrites(grammar)
      let materialized_rules = materialize_left_recursion_rewrites(grammar)
      let rewritten_grammar = rewrite_left_recursive_grammar(grammar)
      let normalized_grammar = if semantic_summary.diagnostics.length() == 0 {
        normalize_grammar(grammar, semantic_summary)
      } else {
        None
      }
      let grammar_atn = if semantic_summary.diagnostics.length() == 0 {
        match normalized_grammar {
          Some(normalized) =>
            Some(build_grammar_atn_from_normalized(normalized))
          None => None
        }
      } else {
        None
      }
      make_frontend_report(
        Some(grammar),
        parse_outcome.diagnostics,
        semantic_summary.diagnostics,
        semantic_summary.semantic_model,
        analyze_left_recursive_rules(grammar),
        rewrite_plans,
        materialized_rules,
        rewritten_grammar,
        normalized_grammar,
        grammar_atn,
      )
    }
    None =>
      make_frontend_report(
        None,
        parse_outcome.diagnostics,
        [],
        None,
        [],
        [],
        [],
        None,
        None,
        None,
      )
  }
}
