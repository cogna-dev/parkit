///|
test "combined plan includes lexer and parser stages" {
  let plan = make_generation_plan(Combined, GeneratorConfig::default())
  assert_eq(target_name(plan.target), "moonbit")
  assert_eq(plan.stages.length(), 11)
  assert_eq(stage_name(plan.stages[0]), "parse-grammar")
  assert_eq(stage_name(plan.stages[6]), "build-lexer-atn")
  assert_eq(stage_name(plan.stages[7]), "build-parser-atn")
  assert_eq(stage_name(plan.stages[8]), "analyze-decisions")
  assert_eq(plan.supports_suite(LeftRecursion), true)
  assert_eq(plan.supports_suite(Listeners), true)
}

///|
test "default config matches antlr listener and visitor defaults" {
  let plan = make_generation_plan(Combined, GeneratorConfig::default())
  assert_eq(plan.emit_listener, true)
  assert_eq(plan.emit_visitor, false)
  assert_eq(plan.emit_base_listener, true)
  assert_eq(plan.emit_base_visitor, false)
}

///|
test "lexer plan omits parser-only stages" {
  let plan = make_generation_plan(Lexer, GeneratorConfig::default())
  assert_eq(plan.stages.length(), 9)
  assert_eq(stage_name(plan.stages[6]), "build-lexer-atn")
  assert_eq(stage_name(plan.stages[7]), "generate-recognizer")
  assert_eq(stage_name(plan.stages[8]), "generate-support-artifacts")
}

///|
test "parser plan keeps decision analysis" {
  let plan = make_generation_plan(Parser, GeneratorConfig::default())
  assert_eq(plan.stages.length(), 10)
  assert_eq(stage_name(plan.stages[6]), "build-parser-atn")
  assert_eq(stage_name(plan.stages[7]), "analyze-decisions")
  assert_eq(plan.supports_suite(FullContextParsing), true)
  assert_eq(plan.supports_suite(SemPredEvalParser), true)
}

///|
test "plan preserves emission toggles" {
  let config = GeneratorConfig::with_emission_flags(
    GeneratorConfig::default(),
    false,
    true,
    false,
    true,
  )
  let plan = make_generation_plan(Combined, config)
  assert_eq(plan.emit_listener, false)
  assert_eq(plan.emit_visitor, true)
  assert_eq(plan.emit_base_listener, false)
  assert_eq(plan.emit_base_visitor, true)
}
