///|
/// Grammar category accepted by the ANTLR-compatible frontend.
pub(all) enum GrammarKind {
  Combined
  Lexer
  Parser
}

///|
/// The first target supported by the generator in this repository.
pub(all) enum GenerationTarget {
  MoonBit
}

///|
/// Stable pipeline stages modeled after ANTLR's tool pipeline.
pub(all) enum PipelineStage {
  ParseGrammar
  IntegrateImports
  NormalizeGrammar
  RunSemanticChecks
  RewriteLeftRecursion
  AssignSymbols
  BuildLexerAtn
  BuildParserAtn
  AnalyzeDecisions
  GenerateRecognizer
  GenerateSupportArtifacts
}

///|
/// Upstream ANTLR compatibility suites that define the baseline target.
pub(all) enum CompatibilitySuite {
  CompositeLexers
  CompositeParsers
  FullContextParsing
  LeftRecursion
  LexerErrors
  LexerExec
  Listeners
  ParseTrees
  ParserErrors
  ParserExec
  SemPredEvalLexer
  SemPredEvalParser
  Sets
}

///|
/// High-level generator toggles kept stable across future implementation slices.
pub struct GeneratorConfig {
  target : GenerationTarget
  emit_listener : Bool
  emit_visitor : Bool
  emit_base_listener : Bool
  emit_base_visitor : Bool
}

///|
pub fn GeneratorConfig::default() -> GeneratorConfig {
  {
    target: MoonBit,
    emit_listener: true,
    emit_visitor: false,
    emit_base_listener: true,
    emit_base_visitor: false,
  }
}

///|
pub fn GeneratorConfig::with_emission_flags(
  self : GeneratorConfig,
  emit_listener : Bool,
  emit_visitor : Bool,
  emit_base_listener : Bool,
  emit_base_visitor : Bool,
) -> GeneratorConfig {
  {
    target: self.target,
    emit_listener,
    emit_visitor,
    emit_base_listener,
    emit_base_visitor,
  }
}

///|
/// A concrete compatibility plan derived from a grammar kind and generator config.
pub struct GenerationPlan {
  grammar_kind : GrammarKind
  target : GenerationTarget
  stages : Array[PipelineStage]
  baseline_suites : Array[CompatibilitySuite]
  emit_listener : Bool
  emit_visitor : Bool
  emit_base_listener : Bool
  emit_base_visitor : Bool
}

///|
pub fn target_name(target : GenerationTarget) -> String {
  match target {
    MoonBit => "moonbit"
  }
}

///|
pub fn stage_name(stage : PipelineStage) -> String {
  match stage {
    ParseGrammar => "parse-grammar"
    IntegrateImports => "integrate-imports"
    NormalizeGrammar => "normalize-grammar"
    RunSemanticChecks => "run-semantic-checks"
    RewriteLeftRecursion => "rewrite-left-recursion"
    AssignSymbols => "assign-symbols"
    BuildLexerAtn => "build-lexer-atn"
    BuildParserAtn => "build-parser-atn"
    AnalyzeDecisions => "analyze-decisions"
    GenerateRecognizer => "generate-recognizer"
    GenerateSupportArtifacts => "generate-support-artifacts"
  }
}

///|
pub fn suite_name(suite : CompatibilitySuite) -> String {
  match suite {
    CompositeLexers => "CompositeLexers"
    CompositeParsers => "CompositeParsers"
    FullContextParsing => "FullContextParsing"
    LeftRecursion => "LeftRecursion"
    LexerErrors => "LexerErrors"
    LexerExec => "LexerExec"
    Listeners => "Listeners"
    ParseTrees => "ParseTrees"
    ParserErrors => "ParserErrors"
    ParserExec => "ParserExec"
    SemPredEvalLexer => "SemPredEvalLexer"
    SemPredEvalParser => "SemPredEvalParser"
    Sets => "Sets"
  }
}

///|
pub fn baseline_compatibility_suites() -> Array[CompatibilitySuite] {
  [
    CompositeLexers,
    CompositeParsers,
    FullContextParsing,
    LeftRecursion,
    LexerErrors,
    LexerExec,
    Listeners,
    ParseTrees,
    ParserErrors,
    ParserExec,
    SemPredEvalLexer,
    SemPredEvalParser,
    Sets,
  ]
}

///|
pub fn default_pipeline_stages(
  grammar_kind : GrammarKind,
) -> Array[PipelineStage] {
  match grammar_kind {
    Combined =>
      [
        ParseGrammar,
        IntegrateImports,
        NormalizeGrammar,
        RunSemanticChecks,
        RewriteLeftRecursion,
        AssignSymbols,
        BuildLexerAtn,
        BuildParserAtn,
        AnalyzeDecisions,
        GenerateRecognizer,
        GenerateSupportArtifacts,
      ]
    Lexer =>
      [
        ParseGrammar,
        IntegrateImports,
        NormalizeGrammar,
        RunSemanticChecks,
        RewriteLeftRecursion,
        AssignSymbols,
        BuildLexerAtn,
        GenerateRecognizer,
        GenerateSupportArtifacts,
      ]
    Parser =>
      [
        ParseGrammar,
        IntegrateImports,
        NormalizeGrammar,
        RunSemanticChecks,
        RewriteLeftRecursion,
        AssignSymbols,
        BuildParserAtn,
        AnalyzeDecisions,
        GenerateRecognizer,
        GenerateSupportArtifacts,
      ]
  }
}

///|
pub fn make_generation_plan(
  grammar_kind : GrammarKind,
  config : GeneratorConfig,
) -> GenerationPlan {
  {
    grammar_kind,
    target: config.target,
    stages: default_pipeline_stages(grammar_kind),
    baseline_suites: baseline_compatibility_suites(),
    emit_listener: config.emit_listener,
    emit_visitor: config.emit_visitor,
    emit_base_listener: config.emit_base_listener,
    emit_base_visitor: config.emit_base_visitor,
  }
}

///|
pub fn GenerationPlan::supports_suite(
  self : GenerationPlan,
  suite : CompatibilitySuite,
) -> Bool {
  for candidate in self.baseline_suites {
    if suite_name(candidate) == suite_name(suite) {
      return true
    }
  }
  false
}
