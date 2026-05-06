///|
fn typed_join_lines(lines : Array[String]) -> String {
  if lines.length() == 0 {
    return ""
  }
  let mut text = lines[0]
  for index = 1; index < lines.length(); index = index + 1 {
    text = text + "\n" + lines[index]
  }
  text
}

///|
fn typed_field_type_text(field : TypedFieldModel) -> String {
  match field.cardinality {
    Required => field.type_name
    Optional => field.type_name + "?"
    Repeated => "Array[" + field.type_name + "]"
    NonEmptyRepeated => "@antlr_tcst.NonEmpty[" + field.type_name + "]"
  }
}

///|
fn typed_grammar_kind_expr(kind : @antlr.GrammarKind) -> String {
  match kind {
    @antlr.Combined => "@antlr.Combined"
    @antlr.Lexer => "@antlr.Lexer"
    @antlr.Parser => "@antlr.Parser"
  }
}

///|
fn typed_string_literal_expr(value : String) -> String {
  let mut result = "\""
  for c in value {
    let escaped = match c {
      '\\' => "\\\\"
      '"' => "\\\""
      '\n' => "\\n"
      '\r' => "\\r"
      '\t' => "\\t"
      _ => String::make(1, c)
    }
    result = result + escaped
  }
  result + "\""
}

///|
fn typed_option_string_expr(value : String?) -> String {
  match value {
    Some(text) => "Some(" + typed_string_literal_expr(text) + ")"
    None => "None"
  }
}

///|
fn typed_join_with_separator(
  values : Array[String],
  separator : String,
) -> String {
  if values.length() == 0 {
    return ""
  }
  let mut text = values[0]
  for index = 1; index < values.length(); index = index + 1 {
    text = text + separator + values[index]
  }
  text
}

///|
fn typed_constructor_variant_lines(rule : TypedRuleModel) -> Array[String] {
  let lines : Array[String] = []
  lines.push("pub(all) enum " + rule.type_name + " {")
  for case_model in rule.constructors {
    lines.push(
      "  " +
      case_model.constructor_name +
      "(" +
      case_model.payload_type_name +
      ")",
    )
  }
  lines.push("}")
  lines
}

///|
fn render_types_file(model : TypedPackageModel) -> String {
  let lines : Array[String] = []
  if model.root_type_name != "RootNode" {
    lines.push("///|")
    lines.push("pub type RootNode = " + model.root_type_name)
  }
  for rule in model.rules {
    for case_model in rule.constructors {
      if lines.length() > 0 {
        lines.push("")
      }
      lines.push("///|")
      lines.push("pub(all) struct " + case_model.payload_type_name + " {")
      lines.push("  span : @antlr.SourceSpan")
      lines.push("  first_token : @antlr_tcst.TerminalToken?")
      lines.push("  last_token : @antlr_tcst.TerminalToken?")
      for field in case_model.fields {
        lines.push(
          "  " + field.field_name + " : " + typed_field_type_text(field),
        )
      }
      lines.push("}")
    }
    lines.push("")
    lines.push("///|")
    for line in typed_constructor_variant_lines(rule) {
      lines.push(line)
    }
  }
  typed_join_lines(lines)
}

///|
fn render_grammar_info_file(model : TypedPackageModel) -> String {
  let lines : Array[String] = []
  lines.push("///|")
  lines.push(
    "let grammar_source : String = " +
    typed_string_literal_expr(model.grammar_source),
  )
  lines.push("")
  lines.push("///|")
  lines.push("let typed_grammar_info : @antlr_tcst.TypedGrammarInfo = {")
  lines.push(
    "  grammar_name: " +
    typed_string_literal_expr(model.grammar.grammar_name) +
    ",",
  )
  lines.push(
    "  grammar_kind: " +
    typed_grammar_kind_expr(model.grammar.grammar_kind) +
    ",",
  )
  lines.push(
    "  start_rule_name: " +
    typed_string_literal_expr(model.grammar.start_rule_name) +
    ",",
  )
  lines.push(
    "  grammar_fingerprint: " +
    typed_string_literal_expr(model.grammar.grammar_fingerprint) +
    ",",
  )
  lines.push(
    "  cst_schema_version: " +
    model.grammar.cst_schema_version.to_string() +
    ",",
  )
  lines.push("}")
  lines.push("")
  lines.push("///|")
  lines.push(
    "/// Return stable grammar metadata for this generated typed CST package.",
  )
  lines.push("///")
  lines.push("/// Example:")
  lines.push("/// let info = grammar_info()")
  lines.push("/// inspect(info.start_rule_name.length() > 0, content=\"true\")")
  lines.push("///")
  lines.push("/// Notes:")
  lines.push(
    "/// - The fingerprint must match the input `CstDocument` before strict lowering succeeds.",
  )
  lines.push(
    "/// - The schema version is pinned to the generic CST contract this package was generated against.",
  )
  lines.push("fn grammar_info() -> @antlr_tcst.TypedGrammarInfo {")
  lines.push("  typed_grammar_info")
  lines.push("}")
  typed_join_lines(lines)
}

///|
fn render_errors_file() -> String {
  typed_join_lines([
    "///|", "type LoweringError = @antlr_tcst.TcstLoweringError",
  ])
}

///|
fn typed_inline_call(callee : String, arguments : Array[String]) -> String {
  callee + "(" + typed_join_with_separator(arguments, ", ") + ")"
}

///|
fn typed_push_match_binding(
  lines : Array[String],
  binding_name : String,
  callee : String,
  arguments : Array[String],
  ok_binding : String,
  multiline_call : Bool,
) -> Unit {
  lines.push("  let " + binding_name + " = match")
  let inline_line = "    " + typed_inline_call(callee, arguments) + " {"
  if multiline_call && inline_line.length() > 82 {
    lines.push("    " + callee + "(")
    for argument in arguments {
      lines.push("      " + argument + ",")
    }
    lines.push("    ) {")
  } else {
    lines.push(inline_line)
  }
  lines.push("    Ok(" + ok_binding + ") => " + ok_binding)
  lines.push("    Err(error) => return Err(error)")
  lines.push("  }")
}

///|
fn typed_first_token_candidate_lines(field : TypedFieldModel) -> Array[String] {
  match field.kind {
    RuleNodeField(_) =>
      match field.cardinality {
        Required => [field.field_name + ".first_token()"]
        Optional =>
          [
            "match " +
            field.field_name +
            " { Some(value) => value.first_token() None => None }",
          ]
        Repeated =>
          [
            "if " + field.field_name + ".length() > 0 {",
            "  " + field.field_name + "[0].first_token()",
            "} else {",
            "  None",
            "}",
          ]
        NonEmptyRepeated => [field.field_name + ".head.first_token()"]
      }
    TokenField(_, _) =>
      match field.cardinality {
        Required => ["Some(" + field.field_name + ")"]
        Optional => [field.field_name]
        Repeated =>
          [
            "if " + field.field_name + ".length() > 0 {",
            "  Some(" + field.field_name + "[0])",
            "} else {",
            "  None",
            "}",
          ]
        NonEmptyRepeated => ["Some(" + field.field_name + ".head)"]
      }
  }
}

///|
fn typed_last_token_candidate_lines(field : TypedFieldModel) -> Array[String] {
  match field.kind {
    RuleNodeField(_) =>
      match field.cardinality {
        Required => [field.field_name + ".last_token()"]
        Optional =>
          [
            "match " +
            field.field_name +
            " { Some(value) => value.last_token() None => None }",
          ]
        Repeated =>
          [
            "if " + field.field_name + ".length() > 0 {",
            "  " +
            field.field_name +
            "[" +
            field.field_name +
            ".length() - 1].last_token()",
            "} else {",
            "  None",
            "}",
          ]
        NonEmptyRepeated =>
          [
            "if " + field.field_name + ".tail.length() > 0 {",
            "  " +
            field.field_name +
            ".tail[" +
            field.field_name +
            ".tail.length() - 1].last_token()",
            "} else {",
            "  " + field.field_name + ".head.last_token()",
            "}",
          ]
      }
    TokenField(_, _) =>
      match field.cardinality {
        Required => ["Some(" + field.field_name + ")"]
        Optional => [field.field_name]
        Repeated =>
          [
            "if " + field.field_name + ".length() > 0 {",
            "  Some(" +
            field.field_name +
            "[" +
            field.field_name +
            ".length() - 1])",
            "} else {",
            "  None",
            "}",
          ]
        NonEmptyRepeated =>
          [
            "if " + field.field_name + ".tail.length() > 0 {",
            "  Some(" +
            field.field_name +
            ".tail[" +
            field.field_name +
            ".tail.length() - 1])",
            "} else {",
            "  Some(" + field.field_name + ".head)",
            "}",
          ]
      }
  }
}

///|
fn typed_all_candidates_single_line(candidates : Array[Array[String]]) -> Bool {
  for candidate_lines in candidates {
    if candidate_lines.length() != 1 {
      return false
    }
  }
  true
}

///|
fn typed_push_query_signature(
  lines : Array[String],
  receiver_type_name : String,
  method_name : String,
  return_type : String,
) -> Unit {
  let signature = "pub fn " +
    receiver_type_name +
    "::" +
    method_name +
    "(self : " +
    receiver_type_name +
    ") -> " +
    return_type +
    " {"
  if signature.length() > 81 {
    lines.push("pub fn " + receiver_type_name + "::" + method_name + "(")
    lines.push("  self : " + receiver_type_name + ",")
    lines.push(") -> " + return_type + " {")
  } else {
    lines.push(signature)
  }
}

///|
fn typed_render_field_loading(
  lines : Array[String],
  rule : TypedRuleModel,
  field : TypedFieldModel,
) -> Unit {
  let slot_result_name = field.field_name + "_slot_values"
  match field.kind {
    RuleNodeField(target_rule_name) => {
      typed_push_match_binding(
        lines,
        slot_result_name,
        "@antlr_tcst.rule_children_for_slot",
        [
          "document",
          "handle",
          field.slot_id.to_string(),
          "\"" + target_rule_name + "\"",
        ],
        "values",
        false,
      )
      match field.cardinality {
        Required => {
          typed_push_match_binding(
            lines,
            field.field_name + "_node_id",
            "@antlr_tcst.required_value",
            [
              slot_result_name,
              "\"" + rule.rule_name + "\"",
              field.slot_id.to_string(),
              "\"" + field.field_name + "\"",
              "handle.node_id",
            ],
            "value",
            true,
          )
          lines.push(
            "  let " +
            field.field_name +
            " = match lower_" +
            typed_lowering_name(target_rule_name) +
            "_node(document, " +
            field.field_name +
            "_node_id) {",
          )
          lines.push("    Ok(value) => value")
          lines.push("    Err(error) => return Err(error)")
          lines.push("  }")
        }
        Optional => {
          typed_push_match_binding(
            lines,
            field.field_name + "_node_id",
            "@antlr_tcst.optional_value",
            [
              slot_result_name,
              "\"" + rule.rule_name + "\"",
              field.slot_id.to_string(),
              "\"" + field.field_name + "\"",
              "handle.node_id",
            ],
            "value",
            true,
          )
          lines.push(
            "  let " +
            field.field_name +
            " = match " +
            field.field_name +
            "_node_id {",
          )
          lines.push("    Some(child_node_id) =>")
          lines.push(
            "      match lower_" +
            typed_lowering_name(target_rule_name) +
            "_node(document, child_node_id) {",
          )
          lines.push("        Ok(value) => Some(value)")
          lines.push("        Err(error) => return Err(error)")
          lines.push("      }")
          lines.push("    None => None")
          lines.push("  }")
        }
        Repeated => {
          lines.push(
            "  let " +
            field.field_name +
            " : Array[" +
            field.type_name +
            "] = []",
          )
          lines.push("  for child_node_id in " + slot_result_name + " {")
          lines.push(
            "    match lower_" +
            typed_lowering_name(target_rule_name) +
            "_node(document, child_node_id) {",
          )
          lines.push("      Ok(value) => " + field.field_name + ".push(value)")
          lines.push("      Err(error) => return Err(error)")
          lines.push("    }")
          lines.push("  }")
        }
        NonEmptyRepeated => {
          typed_push_match_binding(
            lines,
            field.field_name + "_node_ids",
            "@antlr_tcst.non_empty_value",
            [
              slot_result_name,
              "\"" + rule.rule_name + "\"",
              field.slot_id.to_string(),
              "\"" + field.field_name + "\"",
              "handle.node_id",
            ],
            "value",
            true,
          )
          lines.push(
            "  let " +
            field.field_name +
            "_head = match lower_" +
            typed_lowering_name(target_rule_name) +
            "_node(document, " +
            field.field_name +
            "_node_ids.head) {",
          )
          lines.push("    Ok(value) => value")
          lines.push("    Err(error) => return Err(error)")
          lines.push("  }")
          lines.push(
            "  let " +
            field.field_name +
            "_tail : Array[" +
            field.type_name +
            "] = []",
          )
          lines.push(
            "  for child_node_id in " + field.field_name + "_node_ids.tail {",
          )
          lines.push(
            "    match lower_" +
            typed_lowering_name(target_rule_name) +
            "_node(document, child_node_id) {",
          )
          lines.push(
            "      Ok(value) => " + field.field_name + "_tail.push(value)",
          )
          lines.push("      Err(error) => return Err(error)")
          lines.push("    }")
          lines.push("  }")
          lines.push(
            "  let " +
            field.field_name +
            " : @antlr_tcst.NonEmpty[" +
            field.type_name +
            "] = { head: " +
            field.field_name +
            "_head, tail: " +
            field.field_name +
            "_tail }",
          )
        }
      }
    }
    TokenField(symbolic_name, literal_name) => {
      typed_push_match_binding(
        lines,
        slot_result_name,
        "@antlr_tcst.token_children_for_slot",
        [
          "document",
          "handle",
          field.slot_id.to_string(),
          typed_option_string_expr(symbolic_name),
          typed_option_string_expr(literal_name),
        ],
        "values",
        true,
      )
      match field.cardinality {
        Required =>
          typed_push_match_binding(
            lines,
            field.field_name,
            "@antlr_tcst.required_value",
            [
              slot_result_name,
              "\"" + rule.rule_name + "\"",
              field.slot_id.to_string(),
              "\"" + field.field_name + "\"",
              "handle.node_id",
            ],
            "value",
            true,
          )
        Optional =>
          typed_push_match_binding(
            lines,
            field.field_name,
            "@antlr_tcst.optional_value",
            [
              slot_result_name,
              "\"" + rule.rule_name + "\"",
              field.slot_id.to_string(),
              "\"" + field.field_name + "\"",
              "handle.node_id",
            ],
            "value",
            true,
          )
        Repeated =>
          lines.push("  let " + field.field_name + " = " + slot_result_name)
        NonEmptyRepeated =>
          typed_push_match_binding(
            lines,
            field.field_name,
            "@antlr_tcst.non_empty_value",
            [
              slot_result_name,
              "\"" + rule.rule_name + "\"",
              field.slot_id.to_string(),
              "\"" + field.field_name + "\"",
              "handle.node_id",
            ],
            "value",
            true,
          )
      }
    }
  }
}

///|
fn typed_lowering_name(value : String) -> String {
  let mut result = ""
  let mut first = true
  for c in value {
    if c >= 'A' && c <= 'Z' {
      if !first {
        result = result + "_"
      }
      result = result +
        String::make(
          1,
          (c.to_int() - 'A'.to_int() + 'a'.to_int()).unsafe_to_char(),
        )
    } else {
      result = result + String::make(1, c)
    }
    first = false
  }
  result
}

///|
fn render_constructor_lowering(
  rule : TypedRuleModel,
  case_model : TypedConstructorModel,
) -> Array[String] {
  let function_name = "lower_" +
    typed_lowering_name(rule.rule_name) +
    "_" +
    typed_lowering_name(case_model.constructor_name)
  let lines : Array[String] = []
  lines.push("///|")
  lines.push("fn " + function_name + "(")
  lines.push("  document : @antlr_cst.CstDocument,")
  lines.push("  handle : @antlr_tcst.TypedRuleHandle,")
  lines.push(") -> Result[" + rule.type_name + ", LoweringError] {")
  for field in case_model.fields {
    typed_render_field_loading(lines, rule, field)
  }
  lines.push("  let span = @antlr_cst.node_span(document, handle.node_id)")
  let first_candidates : Array[Array[String]] = []
  let last_candidates : Array[Array[String]] = []
  for field in case_model.fields {
    first_candidates.push(typed_first_token_candidate_lines(field))
    last_candidates.push(typed_last_token_candidate_lines(field))
  }
  if typed_all_candidates_single_line(first_candidates) &&
    first_candidates.length() <= 2 {
    let inline_candidates : Array[String] = []
    for candidate_lines in first_candidates {
      inline_candidates.push(candidate_lines[0])
    }
    lines.push(
      "  let first_token = first_present_token([" +
      typed_join_with_separator(inline_candidates, ", ") +
      "])",
    )
  } else {
    lines.push("  let first_token = first_present_token([")
    for candidate_lines in first_candidates {
      for index = 0; index < candidate_lines.length(); index = index + 1 {
        let suffix = if index == candidate_lines.length() - 1 {
          ","
        } else {
          ""
        }
        lines.push("    " + candidate_lines[index] + suffix)
      }
    }
    lines.push("  ])")
  }
  if typed_all_candidates_single_line(last_candidates) &&
    last_candidates.length() <= 2 {
    let inline_candidates : Array[String] = []
    for candidate_lines in last_candidates {
      inline_candidates.push(candidate_lines[0])
    }
    lines.push(
      "  let last_token = last_present_token([" +
      typed_join_with_separator(inline_candidates, ", ") +
      "])",
    )
  } else {
    lines.push("  let last_token = last_present_token([")
    for candidate_lines in last_candidates {
      for index = 0; index < candidate_lines.length(); index = index + 1 {
        let suffix = if index == candidate_lines.length() - 1 {
          ","
        } else {
          ""
        }
        lines.push("    " + candidate_lines[index] + suffix)
      }
    }
    lines.push("  ])")
  }
  let constructor_fields : Array[String] = ["span", "first_token", "last_token"]
  for field in case_model.fields {
    constructor_fields.push(field.field_name)
  }
  lines.push(
    "  Ok(" +
    case_model.constructor_name +
    "({ " +
    typed_join_with_separator(constructor_fields, ", ") +
    " }))",
  )
  lines.push("}")
  lines
}

///|
fn render_rule_dispatch(rule : TypedRuleModel) -> Array[String] {
  let lower_fn_name = "lower_" +
    typed_lowering_name(rule.rule_name) +
    "_node_from_handle"
  let lines : Array[String] = []
  lines.push("///|")
  lines.push("fn " + lower_fn_name + "(")
  lines.push("  document : @antlr_cst.CstDocument,")
  lines.push("  handle : @antlr_tcst.TypedRuleHandle,")
  lines.push(") -> Result[" + rule.type_name + ", LoweringError] {")
  let expected_alts : Array[String] = []
  for case_model in rule.constructors {
    expected_alts.push(case_model.alternative_index.to_string())
  }
  let expected_text = "[" + typed_join_with_separator(expected_alts, ", ") + "]"
  lines.push(
    "  match @antlr_tcst.checked_alternative(handle, " + expected_text + ") {",
  )
  for case_model in rule.constructors {
    lines.push(
      "    Ok(" +
      case_model.alternative_index.to_string() +
      ") => lower_" +
      typed_lowering_name(rule.rule_name) +
      "_" +
      typed_lowering_name(case_model.constructor_name) +
      "(document, handle)",
    )
  }
  lines.push("    Ok(_) => abort(\"unexpected typed alternative dispatch\")")
  lines.push("    Err(error) => Err(error)")
  lines.push("  }")
  lines.push("}")
  lines.push("")
  lines.push("///|")
  lines.push(
    "/// Lower one `" +
    rule.rule_name +
    "` rule node from the generic CST document into `" +
    rule.type_name +
    "`.",
  )
  lines.push("///")
  lines.push("/// Example:")
  lines.push(
    "/// let lowered = lower_" +
    typed_lowering_name(rule.rule_name) +
    "_node(document, document.root)",
  )
  lines.push("/// inspect(lowered is Ok(_), content=\"true\")")
  lines.push("///")
  lines.push("/// Notes:")
  lines.push(
    "/// - The node id must refer to a rule node from the same `CstDocument`.",
  )
  lines.push(
    "/// - Strict lowering rejects schema drift and recovery artifacts before constructing typed values.",
  )
  lines.push("fn lower_" + typed_lowering_name(rule.rule_name) + "_node(")
  lines.push("  document : @antlr_cst.CstDocument,")
  lines.push("  node_id : @antlr_cst.CstNodeId,")
  lines.push(") -> Result[" + rule.type_name + ", LoweringError] {")
  lines.push(
    "  match @antlr_tcst.checked_rule(document, node_id, \"" +
    rule.rule_name +
    "\") {",
  )
  lines.push("    Ok(handle) => " + lower_fn_name + "(document, handle)")
  lines.push("    Err(error) => Err(error)")
  lines.push("  }")
  lines.push("}")
  lines
}

///|
fn render_lowering_file(model : TypedPackageModel) -> String {
  let lines : Array[String] = []
  lines.push("///|")
  lines.push("fn first_present_token(")
  lines.push("  candidates : Array[@antlr_tcst.TerminalToken?],")
  lines.push(") -> @antlr_tcst.TerminalToken? {")
  lines.push("  for candidate in candidates {")
  lines.push("    match candidate {")
  lines.push("      Some(value) => return Some(value)")
  lines.push("      None => ()")
  lines.push("    }")
  lines.push("  }")
  lines.push("  None")
  lines.push("}")
  lines.push("")
  lines.push("///|")
  lines.push("fn last_present_token(")
  lines.push("  candidates : Array[@antlr_tcst.TerminalToken?],")
  lines.push(") -> @antlr_tcst.TerminalToken? {")
  lines.push("  let mut index = candidates.length() - 1")
  lines.push("  while candidates.length() > 0 && index >= 0 {")
  lines.push("    match candidates[index] {")
  lines.push("      Some(value) => return Some(value)")
  lines.push("      None => ()")
  lines.push("    }")
  lines.push("    if index == 0 {")
  lines.push("      break")
  lines.push("    }")
  lines.push("    index = index - 1")
  lines.push("  }")
  lines.push("  None")
  lines.push("}")
  for rule in model.rules {
    for case_model in rule.constructors {
      lines.push("")
      for line in render_constructor_lowering(rule, case_model) {
        lines.push(line)
      }
    }
    lines.push("")
    for line in render_rule_dispatch(rule) {
      lines.push(line)
    }
  }
  lines.push("")
  lines.push("///|")
  lines.push(
    "/// Check whether one generic CST document matches this generated typed package.",
  )
  lines.push("///")
  lines.push("/// Example:")
  lines.push("/// inspect(document_matches(document), content=\"true\")")
  lines.push("///")
  lines.push("/// Notes:")
  lines.push("/// - The probe checks grammar identity and schema version only.")
  lines.push(
    "/// - Strict lowering still rejects recovery artifacts even when this probe returns `true`.",
  )
  lines.push("fn document_matches(document : @antlr_cst.CstDocument) -> Bool {")
  lines.push(
    "  @antlr_tcst.typed_document_matches(document, typed_grammar_info)",
  )
  lines.push("}")
  lines.push("")
  lines.push("///|")
  lines.push(
    "/// Lower the start rule of one matching generic CST document into the generated root type.",
  )
  lines.push("///")
  lines.push("/// Example:")
  lines.push("/// let lowered = lower_root(document)")
  lines.push("/// inspect(lowered is Ok(_), content=\"true\")")
  lines.push("///")
  lines.push("/// Notes:")
  lines.push(
    "/// - The function enforces strict lowering and fails on schema drift or recovery artifacts.",
  )
  lines.push(
    "/// - The returned root type always matches the grammar start rule captured in `typed_grammar_info`.",
  )
  lines.push("fn lower_root(")
  lines.push("  document : @antlr_cst.CstDocument,")
  lines.push(") -> Result[RootNode, LoweringError] {")
  lines.push(
    "  match @antlr_tcst.checked_root_rule(document, typed_grammar_info) {",
  )
  lines.push(
    "    Ok(handle) => lower_" +
    typed_lowering_name(model.root_rule_name) +
    "_node_from_handle(document, handle)",
  )
  lines.push("    Err(error) => Err(error)")
  lines.push("  }")
  lines.push("}")
  typed_join_lines(lines)
}

///|
fn render_parse_file() -> String {
  let lines : Array[String] = []
  lines.push("///|")
  lines.push("fn first_diagnostic_message(")
  lines.push("  diagnostics : Array[@antlr.Diagnostic],")
  lines.push("  fallback : String,")
  lines.push(") -> String {")
  lines.push("  if diagnostics.length() == 0 {")
  lines.push("    fallback")
  lines.push("  } else {")
  lines.push("    diagnostics[0].message")
  lines.push("  }")
  lines.push("}")
  lines.push("")
  lines.push("///|")
  lines.push("fn runtime_atn() -> Result[@antlr.GrammarAtn, String] {")
  lines.push("  let report = @antlr.run_frontend_pipeline(grammar_source)")
  lines.push("  if report.has_errors() {")
  lines.push("    return Err(")
  lines.push("      first_diagnostic_message(")
  lines.push("        report.all_diagnostics(),")
  lines.push("        \"failed to load generated grammar\",")
  lines.push("      ),")
  lines.push("    )")
  lines.push("  }")
  lines.push("  match report.grammar_atn {")
  lines.push("    Some(atn) => Ok(atn)")
  lines.push("    None => Err(\"failed to load generated grammar\")")
  lines.push("  }")
  lines.push("}")
  lines.push("")
  lines.push("///|")
  lines.push(
    "fn first_parser_message(result : @antlr_runtime.ParserRunResult) -> String {",
  )
  lines.push("  if result.diagnostics.length() != 0 {")
  lines.push("    return result.diagnostics[0].message")
  lines.push("  }")
  lines.push("  if result.recovery_events.length() != 0 {")
  lines.push("    return result.recovery_events[0].message")
  lines.push("  }")
  lines.push("  \"input does not match grammar\"")
  lines.push("}")
  lines.push("")
  lines.push("///|")
  lines.push("fn lowering_message() -> String {")
  lines.push("  \"failed to build typed parse result\"")
  lines.push("}")
  lines.push("")
  lines.push("///|")
  lines.push("/// Parse one input string with this generated package.")
  lines.push("///")
  lines.push("/// Example:")
  lines.push("/// let root = parse(\"hello abc\")")
  lines.push("/// inspect(root is Ok(_), content=\"true\")")
  lines.push("///")
  lines.push("/// Notes:")
  lines.push(
    "/// - The function runs the full parse flow for the generated grammar.",
  )
  lines.push(
    "/// - Errors are returned as plain text for direct application or CLI use.",
  )
  lines.push("pub fn parse(input : String) -> Result[RootNode, String] {")
  lines.push("  let atn = match runtime_atn() {")
  lines.push("    Ok(value) => value")
  lines.push("    Err(error) => return Err(error)")
  lines.push("  }")
  lines.push("  let lexer_result = @antlr_runtime.lex_with_atn(")
  lines.push("    atn,")
  lines.push("    input,")
  lines.push("    @antlr_runtime.LexerHostHooks::empty(),")
  lines.push("  )")
  lines.push("  if lexer_result.diagnostics.length() != 0 {")
  lines.push("    return Err(lexer_result.diagnostics[0].message)")
  lines.push("  }")
  lines.push("  let parsed = @antlr_runtime.parse_with_atn(")
  lines.push("    atn,")
  lines.push("    lexer_result.tokens,")
  lines.push("    @antlr_runtime.ParserHostHooks::empty(),")
  lines.push("  )")
  lines.push(
    "  if parsed.diagnostics.length() != 0 || parsed.recovery_events.length() != 0 {",
  )
  lines.push("    return Err(first_parser_message(parsed))")
  lines.push("  }")
  lines.push(
    "  let document = match @antlr_cst.build_cst_document(atn, parsed) {",
  )
  lines.push("    Ok(value) => value")
  lines.push("    Err(error) => return Err(error)")
  lines.push("  }")
  lines.push("  match lower_root(document) {")
  lines.push("    Ok(root) => Ok(root)")
  lines.push("    Err(_) => Err(lowering_message())")
  lines.push("  }")
  lines.push("}")
  typed_join_lines(lines)
}

///|
fn render_query_file(model : TypedPackageModel) -> String {
  let lines : Array[String] = []
  for rule in model.rules {
    lines.push("///|")
    lines.push(
      "/// Return the source span captured on this typed `" +
      rule.rule_name +
      "` node.",
    )
    lines.push("///")
    lines.push("/// Example:")
    lines.push("/// let span = value.span()")
    lines.push("/// ignore(span)")
    lines.push("///")
    lines.push("/// Notes:")
    lines.push(
      "/// - The span is copied from the source generic CST rule node during strict lowering.",
    )
    lines.push("/// - Query methods never re-read the source `CstDocument`.")
    typed_push_query_signature(
      lines,
      rule.type_name,
      "span",
      "@antlr.SourceSpan",
    )
    lines.push("  match self {")
    for case_model in rule.constructors {
      lines.push(
        "    " + case_model.constructor_name + "(fields) => fields.span",
      )
    }
    lines.push("  }")
    lines.push("}")
    lines.push("")
    lines.push("///|")
    lines.push(
      "/// Return the first lexical token reachable from this typed node.",
    )
    lines.push("///")
    lines.push("/// Example:")
    lines.push("/// let token = value.first_token()")
    lines.push("/// ignore(token)")
    lines.push("///")
    lines.push("/// Notes:")
    lines.push("/// - The token was precomputed during strict lowering.")
    lines.push("/// - Empty-token nodes return `None`.")
    typed_push_query_signature(
      lines,
      rule.type_name,
      "first_token",
      "@antlr_tcst.TerminalToken?",
    )
    lines.push("  match self {")
    for case_model in rule.constructors {
      lines.push(
        "    " + case_model.constructor_name + "(fields) => fields.first_token",
      )
    }
    lines.push("  }")
    lines.push("}")
    lines.push("")
    lines.push("///|")
    lines.push(
      "/// Return the last lexical token reachable from this typed node.",
    )
    lines.push("///")
    lines.push("/// Example:")
    lines.push("/// let token = value.last_token()")
    lines.push("/// ignore(token)")
    lines.push("///")
    lines.push("/// Notes:")
    lines.push("/// - The token was precomputed during strict lowering.")
    lines.push("/// - Empty-token nodes return `None`.")
    typed_push_query_signature(
      lines,
      rule.type_name,
      "last_token",
      "@antlr_tcst.TerminalToken?",
    )
    lines.push("  match self {")
    for case_model in rule.constructors {
      lines.push(
        "    " + case_model.constructor_name + "(fields) => fields.last_token",
      )
    }
    lines.push("  }")
    lines.push("}")
    lines.push("")
  }
  typed_join_lines(lines)
}

///|
fn render_package_file() -> String {
  typed_join_lines([
    "import {", "  \"cogna-dev/parkit/antlr/core\" @antlr,", "  \"cogna-dev/parkit/antlr/cst\" @antlr_cst,",
    "  \"cogna-dev/parkit/antlr/tcst\" @antlr_tcst,", "  \"cogna-dev/parkit/antlr/runtime\" @antlr_runtime,",
    "  \"cogna-dev/parkit/antlr/fixture\" @antlr_fixture,", "}",
  ])
}

///|
/// Render the repository-managed file set for one generated typed CST package model.
///
/// Example:
/// let files = generate_typed_package_files(model)
/// inspect(files.length() > 0, content="true")
///
/// Notes:
/// - The emitted files are stable text artifacts intended for checked-in generated fixtures and future tooling.
/// - The generator does not write files to disk; callers choose how to persist or diff the output.
pub fn generate_typed_package_files(
  model : TypedPackageModel,
) -> Array[TypedPackageFile] {
  [
    { relative_path: "moon.pkg", content: render_package_file() },
    { relative_path: "types.mbt", content: render_types_file(model) },
    { relative_path: "info.mbt", content: render_grammar_info_file(model) },
    { relative_path: "errors.mbt", content: render_errors_file() },
    { relative_path: "lowering.mbt", content: render_lowering_file(model) },
    { relative_path: "parse.mbt", content: render_parse_file() },
    { relative_path: "query.mbt", content: render_query_file(model) },
  ]
}

///|
/// Run the typed CST generator end-to-end for one fixed grammar source.
///
/// Example:
/// let files = generate_typed_package("grammar Hello; r : 'x' ID ; ID : [a-z]+ ; WS : [ \r\n\t]+ -> skip ;", "cogna-dev/parkit/antlr/generated/hello")
/// inspect(files is Ok(_), content="true")
///
/// Notes:
/// - The function reuses the main frontend pipeline and only succeeds when semantic analysis succeeds.
/// - Generated file contents remain deterministic for the same grammar source and package name.
pub fn generate_typed_package(
  source : String,
  package_name : String,
) -> Result[Array[TypedPackageFile], String] {
  match build_typed_package_model(source, package_name) {
    Ok(model) => Ok(generate_typed_package_files(model))
    Err(error) => Err(error)
  }
}
