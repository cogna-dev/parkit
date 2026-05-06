///|
/// Lightweight semantic analysis result for the current frontend slice.
pub struct SemanticSummary {
  parser_rule_names : Array[String]
  lexer_rule_names : Array[String]
  start_rule_name : String?
  grammar_fingerprint : String?
  semantic_model : SemanticModel?
  diagnostics : Array[Diagnostic]
}

///|
fn ascii_lower_char(c : Char) -> Char {
  if c >= 'A' && c <= 'Z' {
    (c.to_int() - 'A'.to_int() + 'a'.to_int()).unsafe_to_char()
  } else {
    c
  }
}

///|
fn decapitalize_ascii(value : String) -> String {
  let mut result = ""
  let mut first = true
  for c in value {
    if first {
      result = result + String::make(1, ascii_lower_char(c))
      first = false
    } else {
      result = result + String::make(1, c)
    }
  }
  result
}

///|
fn grammar_is_lexer(kind : GrammarKind) -> Bool {
  match kind {
    Lexer => true
    _ => false
  }
}

///|
fn rule_is_lexer(kind : GrammarRuleKind) -> Bool {
  match kind {
    LexerRule => true
    _ => false
  }
}

///|
fn rule_is_parser(kind : GrammarRuleKind) -> Bool {
  match kind {
    ParserRule => true
    _ => false
  }
}

///|
fn contains_name(values : Array[String], wanted : String) -> Bool {
  for value in values {
    if value == wanted {
      return true
    }
  }
  false
}

///|
fn collect_rule_reference_names(
  elements : Array[GrammarElement],
  into : Array[(String, SourceSpan)],
) -> Unit {
  for element in elements {
    match element.kind {
      RuleReferenceElement(rule_ref) => into.push((rule_ref.name, element.span))
      GroupElement(alternatives) =>
        for alternative in alternatives {
          collect_rule_reference_names(alternative.elements, into)
        }
      _ => ()
    }
  }
}

///|
fn contains_label_conflict(
  all_rule_names : Array[String],
  label : String?,
) -> Bool {
  match label {
    Some(value) => contains_name(all_rule_names, decapitalize_ascii(value))
    None => false
  }
}

///|
fn push_duplicate_name_diagnostic(
  diagnostics : Array[Diagnostic],
  seen_names : Array[String],
  kind : String,
  name : String,
  span : SourceSpan,
) -> Unit {
  if contains_name(seen_names, name) {
    diagnostics.push(
      Diagnostic::error("duplicate " + kind + " `" + name + "`", span),
    )
  } else {
    seen_names.push(name)
  }
}

///|
fn first_start_rule_name(
  grammar_kind : GrammarKind,
  rules : Array[GrammarRuleSpec],
) -> String? {
  for rule in rules {
    if rule_is_parser(rule.kind) {
      return Some(rule.name)
    }
  }
  if grammar_is_lexer(grammar_kind) {
    for rule in rules {
      if rule_is_lexer(rule.kind) && !rule.is_fragment {
        return Some(rule.name)
      }
    }
  }
  None
}

///|
/// Run the Phase 1 semantic closure and produce the stable semantic model when valid.
///
/// Example:
/// let summary = analyze_grammar(grammar)
/// inspect(summary.diagnostics.length(), content="0")
///
/// Notes:
/// - The semantic model is only emitted when no semantic errors are present.
/// - Rule ids and slot ids in the model follow original grammar order and direct-element order.
pub fn analyze_grammar(grammar : GrammarSpec) -> SemanticSummary {
  let parser_rule_names : Array[String] = []
  let lexer_rule_names : Array[String] = []
  let all_rule_names : Array[String] = []
  let diagnostics : Array[Diagnostic] = []
  let seen_rule_names : Array[String] = []
  let seen_channel_names : Array[String] = []
  let seen_mode_names : Array[String] = []
  let seen_token_names : Array[String] = []

  if grammar.rules.length() == 0 {
    diagnostics.push(
      Diagnostic::error("grammar must declare at least one rule", grammar.span),
    )
  }
  if grammar.channel_names.length() > 0 && !grammar_is_lexer(grammar.kind) {
    diagnostics.push(
      Diagnostic::error(
        "channels are only allowed in lexer grammars",
        grammar.span,
      ),
    )
  }
  if grammar.modes.length() > 0 && !grammar_is_lexer(grammar.kind) {
    diagnostics.push(
      Diagnostic::error(
        "modes are only allowed in lexer grammars",
        grammar.span,
      ),
    )
  }

  for token_name in grammar.token_names {
    push_duplicate_name_diagnostic(
      diagnostics,
      seen_token_names,
      "token",
      token_name,
      grammar.span,
    )
  }
  for channel_name in grammar.channel_names {
    push_duplicate_name_diagnostic(
      diagnostics,
      seen_channel_names,
      "channel",
      channel_name,
      grammar.span,
    )
  }
  for mode_name in grammar.modes {
    push_duplicate_name_diagnostic(
      diagnostics,
      seen_mode_names,
      "mode",
      mode_name,
      grammar.span,
    )
  }

  for rule in grammar.rules {
    push_duplicate_name_diagnostic(
      diagnostics,
      seen_rule_names,
      "rule",
      rule.name,
      rule.span,
    )
    all_rule_names.push(rule.name)
    match rule.kind {
      ParserRule => parser_rule_names.push(rule.name)
      LexerRule => {
        lexer_rule_names.push(rule.name)
        if !rule.is_fragment {
          push_duplicate_name_diagnostic(
            diagnostics,
            seen_token_names,
            "token",
            rule.name,
            rule.span,
          )
        }
      }
    }
    match grammar.kind {
      Parser =>
        if rule_is_lexer(rule.kind) {
          diagnostics.push(
            Diagnostic::error(
              "lexer rule `" + rule.name + "` is not allowed in parser grammar",
              rule.span,
            ),
          )
        }
      Lexer =>
        if rule_is_parser(rule.kind) {
          diagnostics.push(
            Diagnostic::error(
              "parser rule `" + rule.name + "` is not allowed in lexer grammar",
              rule.span,
            ),
          )
        }
      _ => ()
    }
  }

  for rule in grammar.rules {
    for alternative in rule.alternatives {
      if contains_label_conflict(all_rule_names, alternative.label) {
        let label = match alternative.label {
          Some(value) => value
          None => abort("expected alternative label")
        }
        diagnostics.push(
          Diagnostic::error(
            "alternative label `" +
            label +
            "` conflicts with rule `" +
            rule.name +
            "`",
            alternative.span,
          ),
        )
      }
      let refs : Array[(String, SourceSpan)] = []
      collect_rule_reference_names(alternative.elements, refs)
      match rule.kind {
        LexerRule =>
          for pair in refs {
            diagnostics.push(
              Diagnostic::error(
                "parser rule reference `" +
                pair.0 +
                "` is not allowed in lexer rule `" +
                rule.name +
                "`",
                pair.1,
              ),
            )
          }
        ParserRule =>
          for pair in refs {
            if !contains_name(parser_rule_names, pair.0) {
              diagnostics.push(
                Diagnostic::error(
                  "undefined parser rule reference `" + pair.0 + "`",
                  pair.1,
                ),
              )
            }
          }
      }
    }
  }

  let semantic_model = if diagnostics.length() == 0 {
    Some(build_semantic_model(grammar))
  } else {
    None
  }
  let start_rule_name = match semantic_model {
    Some(model) =>
      match model.start_rule() {
        Some(rule) => Some(rule.name)
        None => first_start_rule_name(grammar.kind, grammar.rules)
      }
    None => first_start_rule_name(grammar.kind, grammar.rules)
  }
  let grammar_fingerprint = match semantic_model {
    Some(model) => Some(model.grammar_fingerprint)
    None => None
  }

  {
    parser_rule_names,
    lexer_rule_names,
    start_rule_name,
    grammar_fingerprint,
    semantic_model,
    diagnostics,
  }
}
