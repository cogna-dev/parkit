///|
fn find_upstream_analysis(
  analyses : Array[LeftRecursionAnalysis],
  rule_name : String,
) -> LeftRecursionAnalysis {
  for analysis in analyses {
    if analysis.rule_name == rule_name {
      return analysis
    }
  }
  abort("expected upstream left-recursion analysis for rule")
}

///|
fn find_upstream_rewrite_plan(
  plans : Array[LeftRecursionRewritePlan],
  rule_name : String,
) -> LeftRecursionRewritePlan {
  for plan in plans {
    if plan.rule_name == rule_name {
      return plan
    }
  }
  abort("expected upstream rewrite plan for rule")
}

///|
fn supported_upstream_fixtures() -> Array[@antlr_fixture.UpstreamGrammarFixture] {
  @antlr_fixture.supported_frontend_fixtures()
}

///|
fn fixture_label(fixture : @antlr_fixture.UpstreamGrammarFixture) -> String {
  fixture.id + " from " + fixture.upstream_path
}

///|
fn find_fixture_by_id(
  fixtures : Array[@antlr_fixture.UpstreamGrammarFixture],
  fixture_id : String,
) -> @antlr_fixture.UpstreamGrammarFixture {
  for fixture in fixtures {
    if fixture.id == fixture_id {
      return fixture
    }
  }
  abort("expected upstream fixture `" + fixture_id + "`")
}

///|
fn upstream_fixture_failure(
  fixture : @antlr_fixture.UpstreamGrammarFixture,
) -> String? {
  let report = run_frontend_pipeline(fixture.source)
  if report.has_errors() {
    let diagnostics = report.all_diagnostics()
    if diagnostics.length() == 0 {
      return Some("failed without diagnostics")
    }
    return Some(diagnostics[0].message)
  }

  match report.grammar {
    Some(grammar) => {
      if grammar.name != fixture.grammar_name {
        return Some("parsed as grammar `" + grammar.name + "`")
      }
      if grammar.rules.length() != fixture.expected_rule_count {
        return Some(
          "parsed " +
          grammar.rules.length().to_string() +
          " rules instead of " +
          fixture.expected_rule_count.to_string(),
        )
      }
    }
    None => return Some("expected parsed grammar")
  }

  if report.left_recursion_rewrite_plans.length() !=
    fixture.left_recursive_rule_names.length() {
    return Some("produced unexpected rewrite-plan count")
  }
  if report.left_recursion_materialized_rules.length() !=
    fixture.left_recursive_rule_names.length() {
    return Some("produced unexpected materialized-rule count")
  }

  for rule_name in fixture.left_recursive_rule_names {
    let analysis = find_upstream_analysis(
      report.left_recursion_analyses,
      rule_name,
    )
    let plan = find_upstream_rewrite_plan(
      report.left_recursion_rewrite_plans,
      rule_name,
    )
    if !analysis.has_immediate_left_recursion {
      return Some("did not mark left recursion on `" + rule_name + "`")
    }
    if plan.operator_alternatives.length() == 0 {
      return Some("expected operator alternatives for `" + rule_name + "`")
    }
  }

  if fixture.left_recursive_rule_names.length() == 0 {
    match report.left_recursion_rewritten_grammar {
      Some(_) => return Some("unexpected rewritten grammar")
      None => ()
    }
  } else {
    match report.left_recursion_rewritten_grammar {
      Some(_) => ()
      None => return Some("expected rewritten grammar")
    }
  }

  None
}

///|
fn assert_supported_upstream_fixture(
  fixture : @antlr_fixture.UpstreamGrammarFixture,
) -> Unit {
  match fixture.current_gap {
    Some(gap) => abort("supported fixture unexpectedly marked as gap: " + gap)
    None => ()
  }
  match upstream_fixture_failure(fixture) {
    Some(message) =>
      abort("fixture `" + fixture_label(fixture) + "` failed: " + message)
    None => ()
  }
}

///|
test "frontend accepts upstream maven hello fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "maven-hello"),
  )
}

///|
test "frontend accepts upstream maven importsStandard hello fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(
      supported_upstream_fixtures(),
      "maven-imports-standard-hello",
    ),
  )
}

///|
test "frontend accepts upstream maven parser fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "maven-imports-parser"),
  )
}

///|
test "frontend accepts upstream maven lexer fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "maven-imports-lexer"),
  )
}

///|
test "frontend accepts upstream custom hello fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(
      supported_upstream_fixtures(),
      "maven-imports-custom-hello",
    ),
  )
}

///|
test "frontend accepts upstream custom parser fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(
      supported_upstream_fixtures(),
      "maven-imports-custom-parser",
    ),
  )
}

///|
test "frontend accepts upstream custom lexer fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(
      supported_upstream_fixtures(),
      "maven-imports-custom-lexer",
    ),
  )
}

///|
test "frontend accepts upstream import tokens parser fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(
      supported_upstream_fixtures(),
      "maven-import-tokens-simple-parser",
    ),
  )
}

///|
test "frontend accepts upstream base lexer fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(
      supported_upstream_fixtures(),
      "maven-imports-base-lexer",
    ),
  )
}

///|
test "frontend accepts upstream base lexer 2 fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(
      supported_upstream_fixtures(),
      "maven-imports-base-lexer-2",
    ),
  )
}

///|
test "frontend accepts upstream dependencyRemoved hello base fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(
      supported_upstream_fixtures(),
      "maven-dependency-removed-hello-base",
    ),
  )
}

///|
test "frontend accepts upstream custom base lexer fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(
      supported_upstream_fixtures(),
      "maven-imports-custom-base-lexer",
    ),
  )
}

///|
test "frontend accepts upstream csharp arithmetic fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "csharp-arithmetic"),
  )
}

///|
test "frontend accepts upstream js rewriter calc fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "js-rewriter-calc"),
  )
}

///|
test "frontend accepts upstream position adjusting lexer fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(
      supported_upstream_fixtures(),
      "tool-position-adjusting-lexer",
    ),
  )
}

///|
test "frontend accepts upstream psl fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "tool-psl"),
  )
}

///|
test "frontend accepts upstream java lr fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "tool-java-lr"),
  )
}

///|
test "frontend accepts upstream java fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "tool-java"),
  )
}

///|
test "frontend accepts upstream runtime java api fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "runtime-java-api"),
  )
}

///|
test "frontend accepts upstream runtime java api visitor basic fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(
      supported_upstream_fixtures(),
      "runtime-java-api-visitor-basic",
    ),
  )
}

///|
test "frontend accepts upstream runtime java api visitor calc fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(
      supported_upstream_fixtures(),
      "runtime-java-api-visitor-calc",
    ),
  )
}

///|
test "frontend accepts upstream swift lexer a fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "swift-lexer-a"),
  )
}

///|
test "frontend accepts upstream js rewriter abc fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "js-rewriter-abc"),
  )
}

///|
test "frontend accepts upstream swift lexer b fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "swift-lexer-b"),
  )
}

///|
test "frontend accepts upstream swift threading fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "swift-threading"),
  )
}

///|
test "frontend accepts upstream js rewriter calc lexer fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "js-rewriter-calc-lexer"),
  )
}

///|
test "frontend accepts upstream cpp demo lexer fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "cpp-demo-tlexer"),
  )
}

///|
test "frontend accepts upstream cpp demo parser fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "cpp-demo-tparser"),
  )
}

///|
test "frontend accepts upstream asm8080 fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "csharp-asm8080"),
  )
}

///|
test "frontend accepts upstream graphemes fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "java-api-graphemes"),
  )
}

///|
test "frontend accepts upstream xpath lexer fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "python-xpath-lexer"),
  )
}

///|
test "frontend accepts upstream csharp xpath lexer fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "csharp-xpath-lexer"),
  )
}

///|
test "frontend accepts upstream cpp xpath lexer fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "cpp-xpath-lexer"),
  )
}

///|
test "frontend accepts upstream expr fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "python-expr"),
  )
}

///|
test "frontend accepts upstream visitor calc fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "swift-visitor-calc"),
  )
}

///|
test "frontend accepts upstream swift visitor basic fixture" {
  assert_supported_upstream_fixture(
    find_fixture_by_id(supported_upstream_fixtures(), "swift-visitor-basic"),
  )
}
