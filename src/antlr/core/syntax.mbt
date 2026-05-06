///|
priv struct Cursor {
  source : String
  index : Int
  line : Int
  column : Int
}

///|
/// Parse result of the current ANTLR frontend subset.
pub struct ParseOutcome {
  grammar : GrammarSpec?
  diagnostics : Array[Diagnostic]
}

///|
fn Cursor::start(source : String) -> Cursor {
  { source, index: 0, line: 1, column: 0 }
}

///|
fn current_pos(cursor : Cursor) -> SourcePos {
  SourcePos::new(cursor.index, cursor.line, cursor.column)
}

///|
fn span_between(start : Cursor, end : Cursor) -> SourceSpan {
  SourceSpan::new(current_pos(start), current_pos(end))
}

///|
fn cursor_is_eof(cursor : Cursor) -> Bool {
  cursor.index >= cursor.source.length()
}

///|
fn peek_char(cursor : Cursor) -> Char? {
  if cursor_is_eof(cursor) {
    None
  } else {
    Some(cursor.source.get_char(cursor.index).unwrap())
  }
}

///|
fn advance(cursor : Cursor) -> Cursor {
  if cursor_is_eof(cursor) {
    return cursor
  }
  let c = cursor.source.get_char(cursor.index).unwrap()
  if c == '\n' {
    {
      source: cursor.source,
      index: cursor.index + 1,
      line: cursor.line + 1,
      column: 0,
    }
  } else {
    {
      source: cursor.source,
      index: cursor.index + 1,
      line: cursor.line,
      column: cursor.column + 1,
    }
  }
}

///|
fn advance_n(cursor : Cursor, count : Int) -> Cursor {
  let mut cur = cursor
  let mut remaining = count
  while remaining > 0 && !cursor_is_eof(cur) {
    cur = advance(cur)
    remaining = remaining - 1
  }
  cur
}

///|
fn starts_with(cursor : Cursor, text : String) -> Bool {
  let len = text.length()
  if cursor.index + len > cursor.source.length() {
    return false
  }
  cursor.source[cursor.index:cursor.index + len].to_string() == text
}

///|
fn syntax_error(cursor : Cursor, message : String) -> Diagnostic {
  Diagnostic::error(message, SourceSpan::point(current_pos(cursor)))
}

///|
fn skip_line_comment(cursor : Cursor) -> Cursor {
  let mut cur = advance_n(cursor, 2)
  while !cursor_is_eof(cur) {
    match peek_char(cur) {
      Some('\n') => return cur
      Some(_) => cur = advance(cur)
      None => return cur
    }
  }
  cur
}

///|
fn skip_block_comment(cursor : Cursor) -> Cursor {
  let mut cur = advance_n(cursor, 2)
  while !cursor_is_eof(cur) {
    if starts_with(cur, "*/") {
      return advance_n(cur, 2)
    }
    cur = advance(cur)
  }
  cur
}

///|
fn skip_trivia(cursor : Cursor) -> Cursor {
  let mut cur = cursor
  let mut keep_going = true
  while keep_going {
    keep_going = false
    while !cursor_is_eof(cur) {
      match peek_char(cur) {
        Some(c) if @nom.is_whitespace(c) => {
          cur = advance(cur)
          keep_going = true
        }
        _ => break
      }
    }
    if starts_with(cur, "//") {
      cur = skip_line_comment(cur)
      keep_going = true
    } else if starts_with(cur, "/*") {
      cur = skip_block_comment(cur)
      keep_going = true
    }
  }
  cur
}

///|
fn is_identifier_start(c : Char) -> Bool {
  @nom.is_alpha(c) || c == '_'
}

///|
fn is_identifier_continue(c : Char) -> Bool {
  is_identifier_start(c) || @nom.is_digit(c)
}

///|
fn is_uppercase_identifier(name : String) -> Bool {
  if name.length() == 0 {
    return false
  }
  match name.get_char(0) {
    Some(c) => c >= 'A' && c <= 'Z'
    None => false
  }
}

///|
fn trim_ascii(source : String) -> String {
  let mut start = 0
  let mut end = source.length()
  while start < end && @nom.is_whitespace(source.get_char(start).unwrap()) {
    start = start + 1
  }
  while end > start && @nom.is_whitespace(source.get_char(end - 1).unwrap()) {
    end = end - 1
  }
  source[start:end].to_string()
}

///|
fn read_identifier(cursor : Cursor) -> Result[(Cursor, String), Diagnostic] {
  match peek_char(cursor) {
    Some(c) if is_identifier_start(c) => {
      let mut cur = advance(cursor)
      while !cursor_is_eof(cur) {
        match peek_char(cur) {
          Some(next) if is_identifier_continue(next) => cur = advance(cur)
          _ => break
        }
      }
      Ok((cur, cursor.source[cursor.index:cur.index].to_string()))
    }
    _ => Err(syntax_error(cursor, "expected identifier"))
  }
}

///|
fn read_quoted(
  cursor : Cursor,
  quote : Char,
) -> Result[(Cursor, String), Diagnostic] {
  match peek_char(cursor) {
    Some(c) if c == quote => {
      let start = cursor
      let mut cur = advance(cursor)
      let mut escaped = false
      while !cursor_is_eof(cur) {
        let c = peek_char(cur).unwrap()
        cur = advance(cur)
        if escaped {
          escaped = false
        } else if c == '\\' {
          escaped = true
        } else if c == quote {
          return Ok((cur, start.source[start.index:cur.index].to_string()))
        }
      }
      Err(syntax_error(start, "unterminated quoted literal"))
    }
    _ => Err(syntax_error(cursor, "expected quoted literal"))
  }
}

///|
fn read_charset(cursor : Cursor) -> Result[(Cursor, String), Diagnostic] {
  match peek_char(cursor) {
    Some('[') => {
      let start = cursor
      let mut cur = advance(cursor)
      let mut escaped = false
      while !cursor_is_eof(cur) {
        let c = peek_char(cur).unwrap()
        cur = advance(cur)
        if escaped {
          escaped = false
        } else if c == '\\' {
          escaped = true
        } else if c == ']' {
          return Ok((cur, start.source[start.index:cur.index].to_string()))
        }
      }
      Err(syntax_error(start, "unterminated character set"))
    }
    _ => Err(syntax_error(cursor, "expected character set"))
  }
}

///|
fn read_nested_block(
  cursor : Cursor,
  open : Char,
  close : Char,
  label : String,
) -> Result[(Cursor, String), Diagnostic] {
  match peek_char(cursor) {
    Some(c) if c == open => {
      let start = cursor
      let mut cur = advance(cursor)
      let mut depth = 1
      while !cursor_is_eof(cur) {
        if starts_with(cur, "//") {
          cur = skip_line_comment(cur)
          continue
        }
        if starts_with(cur, "/*") {
          cur = skip_block_comment(cur)
          continue
        }
        match peek_char(cur) {
          Some('\'') =>
            match read_quoted(cur, '\'') {
              Ok((next, _)) => cur = next
              Err(diagnostic) => return Err(diagnostic)
            }
          Some('"') =>
            match read_quoted(cur, '"') {
              Ok((next, _)) => cur = next
              Err(diagnostic) => return Err(diagnostic)
            }
          Some(c) => {
            cur = advance(cur)
            if c == open {
              depth = depth + 1
            } else if c == close {
              depth = depth - 1
              if depth == 0 {
                return Ok(
                  (cur, start.source[start.index:cur.index].to_string()),
                )
              }
            }
          }
          None => break
        }
      }
      Err(syntax_error(start, "unterminated " + label))
    }
    _ => Err(syntax_error(cursor, "expected " + label))
  }
}

///|
fn read_until_top_level_char(
  cursor : Cursor,
  stop : Char,
  label : String,
) -> Result[(Cursor, String), Diagnostic] {
  let start = cursor
  let mut cur = cursor
  let mut paren_depth = 0
  let mut bracket_depth = 0
  let mut brace_depth = 0
  while !cursor_is_eof(cur) {
    if starts_with(cur, "//") {
      cur = skip_line_comment(cur)
      continue
    }
    if starts_with(cur, "/*") {
      cur = skip_block_comment(cur)
      continue
    }
    match peek_char(cur) {
      Some('\'') =>
        match read_quoted(cur, '\'') {
          Ok((next, _)) => cur = next
          Err(diagnostic) => return Err(diagnostic)
        }
      Some('"') =>
        match read_quoted(cur, '"') {
          Ok((next, _)) => cur = next
          Err(diagnostic) => return Err(diagnostic)
        }
      Some('(') => {
        paren_depth = paren_depth + 1
        cur = advance(cur)
      }
      Some(')') => {
        if paren_depth > 0 {
          paren_depth = paren_depth - 1
        }
        cur = advance(cur)
      }
      Some('[') => {
        bracket_depth = bracket_depth + 1
        cur = advance(cur)
      }
      Some(']') => {
        if bracket_depth > 0 {
          bracket_depth = bracket_depth - 1
        }
        cur = advance(cur)
      }
      Some('{') => {
        brace_depth = brace_depth + 1
        cur = advance(cur)
      }
      Some('}') => {
        if brace_depth > 0 {
          brace_depth = brace_depth - 1
        }
        cur = advance(cur)
      }
      Some(c) if c == stop &&
        paren_depth == 0 &&
        bracket_depth == 0 &&
        brace_depth == 0 =>
        return Ok((cur, cursor.source[start.index:cur.index].to_string()))
      Some(_) => cur = advance(cur)
      None => break
    }
  }
  Err(syntax_error(start, "unterminated " + label))
}

///|
fn consume_char(
  cursor : Cursor,
  expected : Char,
  label : String,
) -> Result[Cursor, Diagnostic] {
  match peek_char(cursor) {
    Some(c) if c == expected => Ok(advance(cursor))
    _ => Err(syntax_error(cursor, label))
  }
}

///|
fn matches_keyword(cursor : Cursor, keyword : String) -> Bool {
  if !starts_with(cursor, keyword) {
    return false
  }
  let after = cursor.index + keyword.length()
  if after >= cursor.source.length() {
    return true
  }
  let next = cursor.source.get_char(after).unwrap()
  !is_identifier_continue(next)
}

///|
fn consume_keyword(
  cursor : Cursor,
  keyword : String,
) -> Result[Cursor, Diagnostic] {
  if matches_keyword(cursor, keyword) {
    Ok(advance_n(cursor, keyword.length()))
  } else {
    Err(syntax_error(cursor, "expected `" + keyword + "`"))
  }
}

///|
fn parse_imports(
  cursor : Cursor,
) -> Result[(Cursor, Array[String]), Diagnostic] {
  let start = cursor
  let mut cur = match consume_keyword(cursor, "import") {
    Ok(next) => skip_trivia(next)
    Err(diagnostic) => return Err(diagnostic)
  }
  let imports : Array[String] = []
  while true {
    match read_identifier(cur) {
      Ok((next, name)) => {
        imports.push(name)
        cur = skip_trivia(next)
      }
      Err(diagnostic) => return Err(diagnostic)
    }
    match peek_char(cur) {
      Some(',') => cur = skip_trivia(advance(cur))
      Some(';') => return Ok((advance(cur), imports))
      _ => return Err(syntax_error(start, "expected `,` or `;` after import"))
    }
  }
  Err(syntax_error(start, "unterminated import list"))
}

///|
fn parse_identifier_block(
  cursor : Cursor,
  keyword : String,
) -> Result[(Cursor, Array[String]), Diagnostic] {
  let mut cur = match consume_keyword(cursor, keyword) {
    Ok(next) => skip_trivia(next)
    Err(diagnostic) => return Err(diagnostic)
  }
  cur = match consume_char(cur, '{', "expected `{`") {
    Ok(next) => skip_trivia(next)
    Err(diagnostic) => return Err(diagnostic)
  }
  let values : Array[String] = []
  while true {
    cur = skip_trivia(cur)
    match peek_char(cur) {
      Some('}') => return Ok((advance(cur), values))
      Some(_) => {
        match read_identifier(cur) {
          Ok((next, name)) => {
            values.push(name)
            cur = skip_trivia(next)
          }
          Err(diagnostic) => return Err(diagnostic)
        }
        match peek_char(cur) {
          Some(',') => cur = advance(cur)
          Some('}') => ()
          _ => return Err(syntax_error(cur, "expected `,` or `}` in block"))
        }
      }
      None => return Err(syntax_error(cursor, "unterminated identifier block"))
    }
  }
  Err(syntax_error(cursor, "unterminated identifier block"))
}

///|
fn parse_options_block(
  cursor : Cursor,
) -> Result[(Cursor, Array[GrammarOptionEntry]), Diagnostic] {
  let mut cur = match consume_keyword(cursor, "options") {
    Ok(next) => skip_trivia(next)
    Err(diagnostic) => return Err(diagnostic)
  }
  cur = match consume_char(cur, '{', "expected `{`") {
    Ok(next) => skip_trivia(next)
    Err(diagnostic) => return Err(diagnostic)
  }
  let options : Array[GrammarOptionEntry] = []
  while true {
    cur = skip_trivia(cur)
    match peek_char(cur) {
      Some('}') => return Ok((advance(cur), options))
      Some(_) => {
        let option_start = cur
        let name = match read_identifier(cur) {
          Ok((after_name, name)) => {
            cur = skip_trivia(after_name)
            name
          }
          Err(diagnostic) => return Err(diagnostic)
        }
        cur = match consume_char(cur, '=', "expected `=` in options block") {
          Ok(next) => skip_trivia(next)
          Err(diagnostic) => return Err(diagnostic)
        }
        let raw_value = match
          read_until_top_level_char(cur, ';', "option value") {
          Ok((value_end, raw_value)) => {
            cur = advance(value_end)
            raw_value
          }
          Err(diagnostic) => return Err(diagnostic)
        }
        options.push({
          name,
          value: trim_ascii(raw_value),
          span: span_between(option_start, cur),
        })
      }
      None => return Err(syntax_error(cursor, "unterminated options block"))
    }
  }
  Err(syntax_error(cursor, "unterminated options block"))
}

///|
fn parse_named_action(
  cursor : Cursor,
) -> Result[(Cursor, NamedActionEntry), Diagnostic] {
  let start = cursor
  let mut cur = match consume_char(cursor, '@', "expected `@`") {
    Ok(next) => next
    Err(diagnostic) => return Err(diagnostic)
  }
  let first_name = match read_identifier(cur) {
    Ok((after_first, first_name)) => {
      cur = after_first
      first_name
    }
    Err(diagnostic) => return Err(diagnostic)
  }
  let (scope, name) = if starts_with(cur, "::") {
    match read_identifier(advance_n(cur, 2)) {
      Ok((after_second, second_name)) => {
        cur = after_second
        (Some(first_name), second_name)
      }
      Err(diagnostic) => return Err(diagnostic)
    }
  } else {
    (None, first_name)
  }
  cur = skip_trivia(cur)
  match read_nested_block(cur, '{', '}', "named action") {
    Ok((after_body, body)) =>
      Ok(
        (
          after_body,
          { scope, name, body, span: span_between(start, after_body) },
        ),
      )
    Err(diagnostic) => Err(diagnostic)
  }
}

///|
fn parse_mode_header(cursor : Cursor) -> Result[(Cursor, String), Diagnostic] {
  let mut cur = match consume_keyword(cursor, "mode") {
    Ok(next) => skip_trivia(next)
    Err(diagnostic) => return Err(diagnostic)
  }
  let name = match read_identifier(cur) {
    Ok((after_name, name)) => {
      cur = skip_trivia(after_name)
      name
    }
    Err(diagnostic) => return Err(diagnostic)
  }
  cur = match consume_char(cur, ';', "expected `;` after mode declaration") {
    Ok(next) => next
    Err(diagnostic) => return Err(diagnostic)
  }
  Ok((cur, name))
}

///|
fn parse_rule_signature(
  cursor : Cursor,
) -> Result[(Cursor, String?), Diagnostic] {
  let cur = skip_trivia(cursor)
  match peek_char(cur) {
    Some(':') => Ok((cur, None))
    Some(_) =>
      match read_until_top_level_char(cur, ':', "rule signature") {
        Ok((colon_cursor, raw_signature)) => {
          let signature = trim_ascii(raw_signature)
          if signature == "" {
            Ok((colon_cursor, None))
          } else {
            Ok((colon_cursor, Some(signature)))
          }
        }
        Err(diagnostic) => Err(diagnostic)
      }
    None => Err(syntax_error(cur, "expected rule body"))
  }
}

///|
fn parse_alt_option(
  cursor : Cursor,
) -> Result[(Cursor, AlternativeOption), Diagnostic] {
  let start = cursor
  let mut cur = match consume_char(cursor, '<', "expected `<`") {
    Ok(next) => next
    Err(diagnostic) => return Err(diagnostic)
  }
  cur = skip_trivia(cur)
  let name = match read_identifier(cur) {
    Ok((after_name, name)) => {
      cur = skip_trivia(after_name)
      name
    }
    Err(diagnostic) => return Err(diagnostic)
  }
  cur = match consume_char(cur, '=', "expected `=` in alternative option") {
    Ok(next) => skip_trivia(next)
    Err(diagnostic) => return Err(diagnostic)
  }
  let value_raw = match
    read_until_top_level_char(cur, '>', "alternative option") {
    Ok((value_end, value_raw)) => {
      cur = value_end
      value_raw
    }
    Err(diagnostic) => return Err(diagnostic)
  }
  cur = match consume_char(cur, '>', "expected `>` after alternative option") {
    Ok(next) => next
    Err(diagnostic) => return Err(diagnostic)
  }
  Ok(
    (
      cur,
      { name, value: trim_ascii(value_raw), span: span_between(start, cur) },
    ),
  )
}

///|
fn parse_lexer_commands(
  cursor : Cursor,
) -> Result[(Cursor, Array[LexerCommandSpec]), Diagnostic] {
  let mut cur = skip_trivia(cursor)
  if !starts_with(cur, "->") {
    return Err(syntax_error(cur, "expected `->`"))
  }
  cur = skip_trivia(advance_n(cur, 2))
  let commands : Array[LexerCommandSpec] = []
  while true {
    let command_start = cur
    let name = match read_identifier(cur) {
      Ok((after_name, name)) => {
        cur = skip_trivia(after_name)
        name
      }
      Err(diagnostic) => return Err(diagnostic)
    }
    let args = match peek_char(cur) {
      Some('(') =>
        match read_nested_block(cur, '(', ')', "lexer command arguments") {
          Ok((after_args, raw_args)) => {
            cur = skip_trivia(after_args)
            Some(raw_args)
          }
          Err(diagnostic) => return Err(diagnostic)
        }
      _ => None
    }
    commands.push({ name, args, span: span_between(command_start, cur) })
    match peek_char(cur) {
      Some(',') => cur = skip_trivia(advance(cur))
      _ => return Ok((cur, commands))
    }
  }
  Err(syntax_error(cursor, "unterminated lexer command list"))
}

///|
fn is_alternative_stop(cursor : Cursor, terminator : Char) -> Bool {
  let cur = skip_trivia(cursor)
  if cursor_is_eof(cur) {
    return true
  }
  if starts_with(cur, "->") {
    return true
  }
  match peek_char(cur) {
    Some(c) if c == terminator || c == '|' || c == '#' => true
    _ => false
  }
}

///|
fn parse_suffix(cursor : Cursor) -> Result[(Cursor, EbnfSuffix?), Diagnostic] {
  let cur = skip_trivia(cursor)
  match peek_char(cur) {
    Some('?') => {
      let next = advance(cur)
      let greedy = match peek_char(next) {
        Some('?') => false
        _ => true
      }
      let end = if greedy { next } else { advance(next) }
      Ok((end, Some({ kind: OptionalSuffix, greedy })))
    }
    Some('*') => {
      let next = advance(cur)
      let greedy = match peek_char(next) {
        Some('?') => false
        _ => true
      }
      let end = if greedy { next } else { advance(next) }
      Ok((end, Some({ kind: ZeroOrMoreSuffix, greedy })))
    }
    Some('+') => {
      let next = advance(cur)
      let greedy = match peek_char(next) {
        Some('?') => false
        _ => true
      }
      let end = if greedy { next } else { advance(next) }
      Ok((end, Some({ kind: OneOrMoreSuffix, greedy })))
    }
    _ => Ok((cur, None))
  }
}

///|
fn parse_group(
  cursor : Cursor,
) -> Result[(Cursor, Array[GrammarAlternative]), Diagnostic] {
  let mut cur = match consume_char(cursor, '(', "expected `(`") {
    Ok(next) => next
    Err(diagnostic) => return Err(diagnostic)
  }
  cur = skip_trivia(cur)
  match parse_alternative_list(cur, ')') {
    Ok((before_close, alternatives)) => {
      cur = match consume_char(before_close, ')', "expected `)` after group") {
        Ok(next) => next
        Err(diagnostic) => return Err(diagnostic)
      }
      Ok((cur, alternatives))
    }
    Err(diagnostic) => Err(diagnostic)
  }
}

///|
fn parse_atom(
  cursor : Cursor,
) -> Result[(Cursor, GrammarElementKind), Diagnostic] {
  let cur = skip_trivia(cursor)
  match peek_char(cur) {
    Some('(') =>
      match parse_group(cur) {
        Ok((after_group, alternatives)) =>
          Ok((after_group, GroupElement(alternatives)))
        Err(diagnostic) => Err(diagnostic)
      }
    Some('\'') =>
      match read_quoted(cur, '\'') {
        Ok((after_literal, raw_literal)) => {
          let probe = skip_trivia(after_literal)
          if starts_with(probe, "..") {
            let after_dots = skip_trivia(advance_n(probe, 2))
            match read_quoted(after_dots, '\'') {
              Ok((after_range_end, range_end)) =>
                Ok(
                  (
                    after_range_end,
                    RangeElement(raw_literal + " .. " + range_end),
                  ),
                )
              Err(diagnostic) => Err(diagnostic)
            }
          } else {
            Ok((after_literal, StringLiteralElement(raw_literal)))
          }
        }
        Err(diagnostic) => Err(diagnostic)
      }
    Some('[') =>
      match read_charset(cur) {
        Ok((after_set, raw_set)) => Ok((after_set, CharSetElement(raw_set)))
        Err(diagnostic) => Err(diagnostic)
      }
    Some('.') => Ok((advance(cur), WildcardElement))
    Some('{') =>
      match read_nested_block(cur, '{', '}', "action block") {
        Ok((after_block, body)) => {
          let after_ws = skip_trivia(after_block)
          match peek_char(after_ws) {
            Some('?') => {
              let mut after_predicate = skip_trivia(advance(after_ws))
              let mut suffix : String? = None
              match peek_char(after_predicate) {
                Some('<') =>
                  match
                    read_nested_block(
                      after_predicate, '<', '>', "predicate suffix",
                    ) {
                    Ok((after_suffix, raw_suffix)) => {
                      after_predicate = after_suffix
                      suffix = Some(raw_suffix)
                    }
                    Err(diagnostic) => return Err(diagnostic)
                  }
                _ => ()
              }
              Ok((after_predicate, PredicateElement(body, suffix)))
            }
            _ => Ok((after_block, ActionElement(body)))
          }
        }
        Err(diagnostic) => Err(diagnostic)
      }
    Some(c) if is_identifier_start(c) =>
      match read_identifier(cur) {
        Ok((after_name, name)) => {
          let after_ws = skip_trivia(after_name)
          if !is_uppercase_identifier(name) {
            match peek_char(after_ws) {
              Some('[') =>
                match read_nested_block(after_ws, '[', ']', "rule arguments") {
                  Ok((after_args, raw_args)) =>
                    Ok(
                      (
                        after_args,
                        RuleReferenceElement({ name, args: Some(raw_args) }),
                      ),
                    )
                  Err(diagnostic) => Err(diagnostic)
                }
              _ => Ok((after_name, RuleReferenceElement({ name, args: None })))
            }
          } else {
            Ok((after_name, TokenReferenceElement(name)))
          }
        }
        Err(diagnostic) => Err(diagnostic)
      }
    _ => Err(syntax_error(cur, "expected grammar element"))
  }
}

///|
fn parse_rule_element(
  cursor : Cursor,
) -> Result[(Cursor, GrammarElement), Diagnostic] {
  let start = skip_trivia(cursor)
  let mut cur = start
  let negated = match peek_char(cur) {
    Some('~') => {
      cur = skip_trivia(advance(cur))
      true
    }
    _ => false
  }
  let mut label : ElementLabel? = None
  match peek_char(cur) {
    Some(c) if is_identifier_start(c) && !negated =>
      match read_identifier(cur) {
        Ok((after_name, label_name)) => {
          let probe = skip_trivia(after_name)
          if starts_with(probe, "+=") {
            label = Some({ name: label_name, is_list: true })
            cur = skip_trivia(advance_n(probe, 2))
          } else {
            match peek_char(probe) {
              Some('=') => {
                label = Some({ name: label_name, is_list: false })
                cur = skip_trivia(advance(probe))
              }
              _ => ()
            }
          }
        }
        Err(diagnostic) => return Err(diagnostic)
      }
    _ => ()
  }
  let atom_cursor = match label {
    Some(_) => cur
    None => skip_trivia(start)
  }
  let atom_cursor = if negated { cur } else { atom_cursor }
  match parse_atom(atom_cursor) {
    Ok((after_atom, kind)) =>
      match parse_suffix(after_atom) {
        Ok((end, suffix)) =>
          Ok(
            (
              end,
              { label, negated, kind, suffix, span: span_between(start, end) },
            ),
          )
        Err(diagnostic) => Err(diagnostic)
      }
    Err(diagnostic) => Err(diagnostic)
  }
}

///|
fn parse_alternative(
  cursor : Cursor,
  terminator : Char,
) -> Result[(Cursor, GrammarAlternative), Diagnostic] {
  let start = skip_trivia(cursor)
  let mut cur = start
  let options : Array[AlternativeOption] = []
  while (match peek_char(skip_trivia(cur)) {
          Some('<') => true
          _ => false
        }) {
    match parse_alt_option(skip_trivia(cur)) {
      Ok((after_option, option)) => {
        options.push(option)
        cur = skip_trivia(after_option)
      }
      Err(diagnostic) => return Err(diagnostic)
    }
  }
  let elements : Array[GrammarElement] = []
  while !is_alternative_stop(cur, terminator) {
    match parse_rule_element(cur) {
      Ok((after_element, element)) => {
        elements.push(element)
        cur = skip_trivia(after_element)
      }
      Err(diagnostic) => return Err(diagnostic)
    }
  }
  let label = match peek_char(cur) {
    Some('#') =>
      match read_identifier(skip_trivia(advance(cur))) {
        Ok((after_label, label_name)) => {
          cur = skip_trivia(after_label)
          Some(label_name)
        }
        Err(diagnostic) => return Err(diagnostic)
      }
    _ => None
  }
  let commands = if starts_with(cur, "->") {
    match parse_lexer_commands(cur) {
      Ok((after_commands, parsed_commands)) => {
        cur = skip_trivia(after_commands)
        parsed_commands
      }
      Err(diagnostic) => return Err(diagnostic)
    }
  } else {
    []
  }
  Ok(
    (
      cur,
      { options, elements, label, commands, span: span_between(start, cur) },
    ),
  )
}

///|
fn parse_alternative_list(
  cursor : Cursor,
  terminator : Char,
) -> Result[(Cursor, Array[GrammarAlternative]), Diagnostic] {
  let mut cur = skip_trivia(cursor)
  let alternatives : Array[GrammarAlternative] = []
  while true {
    match parse_alternative(cur, terminator) {
      Ok((after_alt, alternative)) => {
        alternatives.push(alternative)
        cur = skip_trivia(after_alt)
      }
      Err(diagnostic) => return Err(diagnostic)
    }
    match peek_char(cur) {
      Some('|') => cur = skip_trivia(advance(cur))
      Some(c) if c == terminator => return Ok((cur, alternatives))
      _ => return Err(syntax_error(cur, "expected `|` or rule terminator"))
    }
  }
  Err(syntax_error(cursor, "unterminated alternative list"))
}

///|
fn parse_rule_trailers(
  cursor : Cursor,
) -> Result[(Cursor, Array[RuleTrailer]), Diagnostic] {
  let mut cur = skip_trivia(cursor)
  let trailers : Array[RuleTrailer] = []
  while true {
    if matches_keyword(cur, "catch") {
      let start = cur
      cur = match consume_keyword(cur, "catch") {
        Ok(next) => skip_trivia(next)
        Err(diagnostic) => return Err(diagnostic)
      }
      let header = match
        read_nested_block(cur, '[', ']', "rule catch arguments") {
        Ok((after_header, header)) => {
          cur = skip_trivia(after_header)
          header
        }
        Err(diagnostic) => return Err(diagnostic)
      }
      let body = match read_nested_block(cur, '{', '}', "rule catch block") {
        Ok((after_body, body)) => {
          cur = skip_trivia(after_body)
          body
        }
        Err(diagnostic) => return Err(diagnostic)
      }
      trailers.push({
        kind: CatchRuleTrailer,
        header: Some(header),
        body,
        span: span_between(start, cur),
      })
    } else if matches_keyword(cur, "finally") {
      let start = cur
      cur = match consume_keyword(cur, "finally") {
        Ok(next) => skip_trivia(next)
        Err(diagnostic) => return Err(diagnostic)
      }
      let body = match read_nested_block(cur, '{', '}', "rule finally block") {
        Ok((after_body, body)) => {
          cur = skip_trivia(after_body)
          body
        }
        Err(diagnostic) => return Err(diagnostic)
      }
      trailers.push({
        kind: FinallyRuleTrailer,
        header: None,
        body,
        span: span_between(start, cur),
      })
    } else {
      return Ok((cur, trailers))
    }
  }
  Err(syntax_error(cursor, "unterminated rule trailers"))
}

///|
fn parse_rule(
  cursor : Cursor,
  grammar_kind : GrammarKind,
  current_mode : String?,
) -> Result[(Cursor, GrammarRuleSpec), Diagnostic] {
  let start = skip_trivia(cursor)
  let (after_fragment, is_fragment) = if matches_keyword(start, "fragment") {
    match grammar_kind {
      Parser => (start, false)
      _ =>
        match consume_keyword(start, "fragment") {
          Ok(next) => (skip_trivia(next), true)
          Err(diagnostic) => return Err(diagnostic)
        }
    }
  } else {
    (start, false)
  }
  let (after_name, name) = match read_identifier(after_fragment) {
    Ok(result) => result
    Err(diagnostic) => return Err(diagnostic)
  }
  let kind = if is_uppercase_identifier(name) { LexerRule } else { ParserRule }
  if is_fragment {
    match kind {
      ParserRule =>
        return Err(syntax_error(start, "fragment rules must be lexer rules"))
      LexerRule => ()
    }
  }
  let (before_colon, signature) = match parse_rule_signature(after_name) {
    Ok(result) => result
    Err(diagnostic) => return Err(diagnostic)
  }
  let mut cur = match
    consume_char(before_colon, ':', "expected `:` after rule name") {
    Ok(next) => next
    Err(diagnostic) => return Err(diagnostic)
  }
  cur = skip_trivia(cur)
  let (before_semicolon, alternatives) = match
    parse_alternative_list(cur, ';') {
    Ok(result) => result
    Err(diagnostic) => return Err(diagnostic)
  }
  cur = match consume_char(before_semicolon, ';', "expected `;` after rule") {
    Ok(next) => next
    Err(diagnostic) => return Err(diagnostic)
  }
  let trailers = match parse_rule_trailers(cur) {
    Ok((after_trailers, trailers)) => {
      cur = after_trailers
      trailers
    }
    Err(diagnostic) => return Err(diagnostic)
  }
  Ok(
    (
      cur,
      {
        name,
        kind,
        is_fragment,
        signature,
        mode: current_mode,
        alternatives,
        trailers,
        span: span_between(start, cur),
      },
    ),
  )
}

///|
fn parse_grammar_internal(
  source : String,
) -> Result[(Cursor, GrammarSpec), Diagnostic] {
  let start = Cursor::start(source)
  let mut cur = skip_trivia(start)
  let grammar_kind = if matches_keyword(cur, "parser") {
    cur = match consume_keyword(cur, "parser") {
      Ok(next) => skip_trivia(next)
      Err(diagnostic) => return Err(diagnostic)
    }
    cur = match consume_keyword(cur, "grammar") {
      Ok(next) => skip_trivia(next)
      Err(diagnostic) => return Err(diagnostic)
    }
    Parser
  } else if matches_keyword(cur, "lexer") {
    cur = match consume_keyword(cur, "lexer") {
      Ok(next) => skip_trivia(next)
      Err(diagnostic) => return Err(diagnostic)
    }
    cur = match consume_keyword(cur, "grammar") {
      Ok(next) => skip_trivia(next)
      Err(diagnostic) => return Err(diagnostic)
    }
    Lexer
  } else {
    cur = match consume_keyword(cur, "grammar") {
      Ok(next) => skip_trivia(next)
      Err(diagnostic) => return Err(diagnostic)
    }
    Combined
  }
  let grammar_name = match read_identifier(cur) {
    Ok((after_name, grammar_name)) => {
      cur = skip_trivia(after_name)
      grammar_name
    }
    Err(diagnostic) => return Err(diagnostic)
  }
  cur = match consume_char(cur, ';', "expected `;` after grammar header") {
    Ok(next) => next
    Err(diagnostic) => return Err(diagnostic)
  }

  let imports : Array[String] = []
  let options : Array[GrammarOptionEntry] = []
  let token_names : Array[String] = []
  let channel_names : Array[String] = []
  let named_actions : Array[NamedActionEntry] = []
  let modes : Array[String] = []
  let rules : Array[GrammarRuleSpec] = []
  let mut current_mode : String? = None

  while true {
    cur = skip_trivia(cur)
    if cursor_is_eof(cur) {
      break
    }
    if matches_keyword(cur, "import") {
      match parse_imports(cur) {
        Ok((after_imports, imported_names)) => {
          for imported_name in imported_names {
            imports.push(imported_name)
          }
          cur = after_imports
        }
        Err(diagnostic) => return Err(diagnostic)
      }
      continue
    }
    if matches_keyword(cur, "options") {
      match parse_options_block(cur) {
        Ok((after_options, parsed_options)) => {
          for option in parsed_options {
            options.push(option)
          }
          cur = after_options
        }
        Err(diagnostic) => return Err(diagnostic)
      }
      continue
    }
    if matches_keyword(cur, "tokens") {
      match parse_identifier_block(cur, "tokens") {
        Ok((after_tokens, parsed_tokens)) => {
          for token_name in parsed_tokens {
            token_names.push(token_name)
          }
          cur = after_tokens
        }
        Err(diagnostic) => return Err(diagnostic)
      }
      continue
    }
    if matches_keyword(cur, "channels") {
      match parse_identifier_block(cur, "channels") {
        Ok((after_channels, parsed_channels)) => {
          for channel_name in parsed_channels {
            channel_names.push(channel_name)
          }
          cur = after_channels
        }
        Err(diagnostic) => return Err(diagnostic)
      }
      continue
    }
    if matches_keyword(cur, "mode") {
      match parse_mode_header(cur) {
        Ok((after_mode, mode_name)) => {
          modes.push(mode_name)
          current_mode = Some(mode_name)
          cur = after_mode
        }
        Err(diagnostic) => return Err(diagnostic)
      }
      continue
    }
    match peek_char(cur) {
      Some('@') =>
        match parse_named_action(cur) {
          Ok((after_action, action)) => {
            named_actions.push(action)
            cur = after_action
          }
          Err(diagnostic) => return Err(diagnostic)
        }
      Some(c) if is_identifier_start(c) =>
        match parse_rule(cur, grammar_kind, current_mode) {
          Ok((after_rule, rule)) => {
            rules.push(rule)
            cur = after_rule
          }
          Err(diagnostic) => return Err(diagnostic)
        }
      _ => return Err(syntax_error(cur, "unexpected token at top level"))
    }
  }

  Ok(
    (
      cur,
      {
        kind: grammar_kind,
        name: grammar_name,
        imports,
        options,
        token_names,
        channel_names,
        named_actions,
        modes,
        rules,
        span: span_between(start, cur),
      },
    ),
  )
}

///|
pub fn parse_grammar(source : String) -> ParseOutcome {
  match parse_grammar_internal(source) {
    Ok((cursor, grammar)) => {
      let rest = skip_trivia(cursor)
      if cursor_is_eof(rest) {
        { grammar: Some(grammar), diagnostics: [] }
      } else {
        {
          grammar: None,
          diagnostics: [syntax_error(rest, "unexpected trailing input")],
        }
      }
    }
    Err(diagnostic) => { grammar: None, diagnostics: [diagnostic] }
  }
}
