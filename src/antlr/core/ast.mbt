///|
/// Parsed option entry from a grammar-level options block.
pub struct GrammarOptionEntry {
  name : String
  value : String
  span : SourceSpan
}

///|
/// Named action such as @members or @parser::members.
pub struct NamedActionEntry {
  scope : String?
  name : String
  body : String
  span : SourceSpan
}

///|
/// Distinguishes parser and lexer rule definitions inside a grammar.
pub(all) enum GrammarRuleKind {
  ParserRule
  LexerRule
}

///|
/// Parsed rule reference, preserving optional raw argument text.
pub struct RuleReference {
  name : String
  args : String?
}

///|
/// Label attached to a rule element using = or +=.
pub struct ElementLabel {
  name : String
  is_list : Bool
}

///|
/// Supported EBNF suffix kinds for the grammar subset parser.
pub(all) enum EbnfSuffixKind {
  OptionalSuffix
  ZeroOrMoreSuffix
  OneOrMoreSuffix
}

///|
/// Parsed EBNF suffix, including nongreedy marker.
pub struct EbnfSuffix {
  kind : EbnfSuffixKind
  greedy : Bool
}

///|
/// Alternative option such as <assoc=right>.
pub struct AlternativeOption {
  name : String
  value : String
  span : SourceSpan
}

///|
/// Lexer command after ->.
pub struct LexerCommandSpec {
  name : String
  args : String?
  span : SourceSpan
}

///|
/// One grammar alternative.
pub struct GrammarAlternative {
  options : Array[AlternativeOption]
  elements : Array[GrammarElement]
  label : String?
  commands : Array[LexerCommandSpec]
  span : SourceSpan
}

///|
/// Trailing catch/finally clause attached to a parser rule.
pub(all) enum RuleTrailerKind {
  CatchRuleTrailer
  FinallyRuleTrailer
}

///|
/// Structured rule trailer kept after the terminating semicolon.
pub struct RuleTrailer {
  kind : RuleTrailerKind
  header : String?
  body : String
  span : SourceSpan
}

///|
/// Supported rule element kinds for the current grammar frontend.
pub(all) enum GrammarElementKind {
  RuleReferenceElement(RuleReference)
  TokenReferenceElement(String)
  StringLiteralElement(String)
  RangeElement(String)
  CharSetElement(String)
  WildcardElement
  GroupElement(Array[GrammarAlternative])
  ActionElement(String)
  PredicateElement(String, String?)
}

///|
/// One rule element, optionally negated, labeled, or quantified.
pub struct GrammarElement {
  label : ElementLabel?
  negated : Bool
  kind : GrammarElementKind
  suffix : EbnfSuffix?
  span : SourceSpan
}

///|
/// Parsed rule specification.
pub struct GrammarRuleSpec {
  name : String
  kind : GrammarRuleKind
  is_fragment : Bool
  signature : String?
  mode : String?
  alternatives : Array[GrammarAlternative]
  trailers : Array[RuleTrailer]
  span : SourceSpan
}

///|
/// Parsed grammar root.
pub struct GrammarSpec {
  kind : GrammarKind
  name : String
  imports : Array[String]
  options : Array[GrammarOptionEntry]
  token_names : Array[String]
  channel_names : Array[String]
  named_actions : Array[NamedActionEntry]
  modes : Array[String]
  rules : Array[GrammarRuleSpec]
  span : SourceSpan
}

///|
pub fn grammar_rule_kind_name(kind : GrammarRuleKind) -> String {
  match kind {
    ParserRule => "parser"
    LexerRule => "lexer"
  }
}

///|
pub fn ebnf_suffix_kind_name(kind : EbnfSuffixKind) -> String {
  match kind {
    OptionalSuffix => "optional"
    ZeroOrMoreSuffix => "zero-or-more"
    OneOrMoreSuffix => "one-or-more"
  }
}
