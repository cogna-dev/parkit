///|
fn expect_normalized(source : String) -> NormalizedGrammar {
  let grammar = expect_parsed(source)
  let summary = analyze_grammar(grammar)
  if summary.diagnostics.length() != 0 {
    abort(summary.diagnostics[0].message)
  }
  match normalize_grammar(grammar, summary) {
    Some(normalized) => normalized
    None => abort("expected normalized grammar")
  }
}

///|
test "normalize plain grammar preserves direct slot origins" {
  let normalized = expect_normalized(
    "grammar Hello;\n\nr : 'hello' ID ;\nID : [a-z]+ ;\nWS : [ \\r\\t\\n]+ -> skip ;\n",
  )
  match normalized.find_rule("r") {
    Some(rule) => {
      assert_eq(rule.rewritten, false)
      assert_eq(rule.alternatives.length(), 1)
      let alternative = rule.alternatives[0]
      assert_eq(alternative.elements.length(), 2)
      match alternative.public_origin {
        Some(origin) => assert_eq(origin.alternative_index, 1)
        None => abort("expected public alternative origin")
      }
      match alternative.elements[0].origin.slot {
        Some(slot) => assert_eq(slot.slot_id, 0)
        None => abort("expected direct slot origin")
      }
      match alternative.elements[1].origin.slot {
        Some(slot) => assert_eq(slot.slot_id, 1)
        None => abort("expected direct slot origin")
      }
    }
    None => abort("expected normalized rule r")
  }
}

///|
test "normalize left recursion keeps original alternative and synthetic origins" {
  let normalized = expect_normalized(
    "grammar Expr;\n\nexpr\n  : expr '*' expr # Mul\n  | '-' expr # Neg\n  | ID # Atom\n  ;\n\nID : [a-z]+ ;\nWS : [ \\r\\t\\n]+ -> skip ;\n",
  )
  match normalized.find_rule("expr") {
    Some(rule) => {
      assert_eq(rule.rewritten, true)
      assert_eq(rule.alternatives.length(), 1)
      let top = rule.alternatives[0]
      assert_eq(top.public_origin is None, true)
      assert_eq(top.elements.length(), 2)
      match top.elements[0].kind {
        GroupElement(primary_alternatives) => {
          assert_eq(primary_alternatives.length(), 2)
          match primary_alternatives[0].public_origin {
            Some(origin) => assert_eq(origin.alternative_index, 2)
            None => abort("expected primary public origin")
          }
        }
        _ => abort("expected primary synthetic group")
      }
      match top.elements[1].kind {
        GroupElement(operator_alternatives) => {
          assert_eq(operator_alternatives.length(), 1)
          let operator_alt = operator_alternatives[0]
          match operator_alt.public_origin {
            Some(origin) => assert_eq(origin.alternative_index, 1)
            None => abort("expected operator public origin")
          }
          match operator_alt.elements[0].origin.synthetic_kind {
            Some(LeftRecPrecedencePredicate) => ()
            _ => abort("expected synthetic precedence predicate")
          }
          match operator_alt.elements[1].origin.slot {
            Some(slot) => assert_eq(slot.slot_id, 1)
            None => abort("expected original operator slot origin")
          }
        }
        _ => abort("expected operator synthetic group")
      }
    }
    None => abort("expected normalized expr rule")
  }
}
