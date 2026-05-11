///|
fn expect_parsed_for_left_recursion(source : String) -> GrammarSpec {
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
fn find_analysis_by_name(
  analyses : Array[LeftRecursionAnalysis],
  rule_name : String,
) -> LeftRecursionAnalysis {
  for analysis in analyses {
    if analysis.rule_name == rule_name {
      return analysis
    }
  }
  abort("expected left-recursion analysis for rule")
}

///|
fn find_rewrite_plan_by_name(
  plans : Array[LeftRecursionRewritePlan],
  rule_name : String,
) -> LeftRecursionRewritePlan {
  for plan in plans {
    if plan.rule_name == rule_name {
      return plan
    }
  }
  abort("expected left-recursion rewrite plan for rule")
}

///|
test "classify prefix binary suffix and primary alternatives" {
  let grammar = expect_parsed_for_left_recursion(
    "grammar Expr;\n\nexpr\n  : '-' expr # Neg\n  | expr '*' expr # Mul\n  | expr '++' # PostInc\n  | ID # Atom\n  ;\n\nID : [a-z]+ ;\nWS : [ \\r\\t\\n]+ -> skip ;\n",
  )
  let analysis = find_analysis_by_name(
    analyze_left_recursive_rules(grammar),
    "expr",
  )
  assert_eq(analysis.has_immediate_left_recursion, true)
  assert_eq(analysis.binary_alternatives.length(), 1)
  assert_eq(analysis.suffix_alternatives.length(), 1)
  assert_eq(analysis.prefix_alternatives.length(), 1)
  assert_eq(analysis.primary_alternatives.length(), 1)
  assert_eq(analysis.binary_alternatives[0].alt_index, 2)
  assert_eq(analysis.suffix_alternatives[0].alt_index, 3)
  assert_eq(analysis.prefix_alternatives[0].alt_index, 1)
  assert_eq(analysis.primary_alternatives[0].alt_index, 4)
}

///|
test "keep associativity and ignore leading predicates in classification" {
  let grammar = expect_parsed_for_left_recursion(
    "grammar Assoc;\n\nexpr\n  : <assoc=right> {enabled()}? expr '=' expr # Assign\n  | value # Value\n  ;\n\nvalue : ID ;\nID : [a-z]+ ;\nWS : [ \\r\\t\\n]+ -> skip ;\n",
  )
  let analysis = find_analysis_by_name(
    analyze_left_recursive_rules(grammar),
    "expr",
  )
  assert_eq(analysis.binary_alternatives.length(), 1)
  assert_eq(analysis.primary_alternatives.length(), 1)
  match analysis.binary_alternatives[0].associativity {
    Some(assoc) => assert_eq(operator_associativity_name(assoc), "right")
    None => abort("expected associativity")
  }
  match analysis.binary_alternatives[0].label {
    Some(label) => assert_eq(label, "Assign")
    None => abort("expected alternative label")
  }
}

///|
test "rewrite plan groups prefix into primary and strips operator recursion" {
  let grammar = expect_parsed_for_left_recursion(
    "grammar Expr;\n\nexpr\n  : '-' expr # Neg\n  | expr '*' expr # Mul\n  | expr '++' # PostInc\n  | ID # Atom\n  ;\n\nID : [a-z]+ ;\nWS : [ \\r\\t\\n]+ -> skip ;\n",
  )
  let plan = find_rewrite_plan_by_name(
    plan_left_recursive_rewrites(grammar),
    "expr",
  )
  assert_eq(plan.precedence_argument_name, "p")
  assert_eq(plan.primary_alternatives.length(), 2)
  assert_eq(plan.operator_alternatives.length(), 2)
  assert_eq(plan.primary_alternatives[0].original_alt_index, 1)
  assert_eq(plan.primary_alternatives[1].original_alt_index, 4)
  match plan.primary_alternatives[0].elements[1].kind {
    RuleReferenceElement(rule_ref) => {
      assert_eq(rule_ref.name, "expr")
      match rule_ref.args {
        Some(args) => assert_eq(args, "[4]")
        None => abort("expected rewritten precedence arg")
      }
    }
    _ => abort("expected rewritten recursive reference in prefix alternative")
  }
  assert_eq(plan.operator_alternatives[0].original_alt_index, 2)
  assert_eq(plan.operator_alternatives[0].precedence, 3)
  match plan.operator_alternatives[0].next_precedence {
    Some(next_precedence) => assert_eq(next_precedence, 4)
    None => abort("expected next precedence")
  }
  match plan.operator_alternatives[0].elements[0].kind {
    StringLiteralElement(text) => assert_eq(text, "'*'")
    _ => abort("expected stripped operator token")
  }
  match plan.operator_alternatives[0].elements[1].kind {
    RuleReferenceElement(rule_ref) => {
      assert_eq(rule_ref.name, "expr")
      match rule_ref.args {
        Some(args) => assert_eq(args, "[4]")
        None => abort("expected rewritten precedence arg")
      }
    }
    _ => abort("expected rewritten rhs recursive reference")
  }
  assert_eq(plan.operator_alternatives[1].original_alt_index, 3)
  match plan.operator_alternatives[1].elements[0].kind {
    StringLiteralElement(text) => assert_eq(text, "'++'")
    _ => abort("expected suffix operator token")
  }
}

///|
test "rewrite plan preserves right associativity precedence" {
  let grammar = expect_parsed_for_left_recursion(
    "grammar Assoc;\n\nexpr\n  : <assoc=right> expr '=' expr # Assign\n  | value # Value\n  ;\n\nvalue : ID ;\nID : [a-z]+ ;\nWS : [ \\r\\t\\n]+ -> skip ;\n",
  )
  let plan = find_rewrite_plan_by_name(
    plan_left_recursive_rewrites(grammar),
    "expr",
  )
  assert_eq(plan.primary_alternatives.length(), 1)
  assert_eq(plan.operator_alternatives.length(), 1)
  assert_eq(plan.operator_alternatives[0].precedence, 2)
  match plan.operator_alternatives[0].next_precedence {
    Some(next_precedence) => assert_eq(next_precedence, 2)
    None => abort("expected right-associative next precedence")
  }
  match plan.operator_alternatives[0].associativity {
    RightAssociative => ()
    _ => abort("expected right associativity")
  }
  match plan.operator_alternatives[0].elements[1].kind {
    RuleReferenceElement(rule_ref) =>
      match rule_ref.args {
        Some(args) => assert_eq(args, "[2]")
        None => abort("expected preserved right-associative precedence arg")
      }
    _ => abort("expected rhs recursive reference")
  }
}

///|
test "render synthetic left-recursive rule text" {
  let grammar = expect_parsed_for_left_recursion(
    "grammar Expr;\n\nexpr\n  : '-' expr # Neg\n  | expr '*' expr # Mul\n  | expr '++' # PostInc\n  | ID # Atom\n  ;\n\nID : [a-z]+ ;\nWS : [ \\r\\t\\n]+ -> skip ;\n",
  )
  let plan = find_rewrite_plan_by_name(
    plan_left_recursive_rewrites(grammar),
    "expr",
  )
  let rendered = render_left_recursion_rewrite_rule(plan)
  assert_eq(
    rendered, "expr[p]\n  : ('-' expr[4]\n    | ID)\n    ({3 >= $p}? '*' expr[4]\n    | {2 >= $p}? '++')*\n  ;",
  )
}

///|
test "rendered synthetic rule is parseable by current frontend" {
  let grammar = expect_parsed_for_left_recursion(
    "grammar Expr;\n\nexpr\n  : <assoc=right> expr '=' expr # Assign\n  | value # Value\n  ;\n\nvalue : ID ;\nID : [a-z]+ ;\nWS : [ \\r\\t\\n]+ -> skip ;\n",
  )
  let plan = find_rewrite_plan_by_name(
    plan_left_recursive_rewrites(grammar),
    "expr",
  )
  let synthetic_source = "grammar Synthetic;\n\n" +
    render_left_recursion_rewrite_rule(plan) +
    "\n\nvalue : ID ;\nID : [a-z]+ ;\nWS : [ \\r\\t\\n]+ -> skip ;\n"
  let outcome = parse_grammar(synthetic_source)
  assert_eq(outcome.diagnostics.length(), 0)
  match outcome.grammar {
    Some(rewritten_grammar) => {
      assert_eq(rewritten_grammar.rules[0].name, "expr")
      match rewritten_grammar.rules[0].signature {
        Some(signature) => assert_eq(signature, "[p]")
        None => abort("expected precedence signature")
      }
    }
    None => abort("expected rendered synthetic grammar to parse")
  }
}
