// Copyright 2024 cogna-dev
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// A JSON value, as described by ECMA-404.
///
/// References: https://ecma-international.org/publications-and-standards/standards/ecma-404/
pub enum JsonValue {
  /// JSON null
  Null
  /// JSON true / false
  Bool(Bool)
  /// JSON number (stored as Double)
  Number(Double)
  /// JSON string
  Str(String)
  /// JSON array
  Array(Array[JsonValue])
  /// JSON object (preserves insertion order)
  Object(Array[(String, JsonValue)])
}

///|
pub impl Show for JsonValue with output(self, logger) {
  match self {
    Null => logger.write_string("null")
    Bool(b) => logger.write_string(if b { "true" } else { "false" })
    Number(n) => logger.write_string(n.to_string())
    Str(s) => {
      logger.write_string("\"")
      logger.write_string(s)
      logger.write_string("\"")
    }
    Array(arr) => {
      logger.write_string("[")
      for i, v in arr {
        if i > 0 {
          logger.write_string(",")
        }
        v.output(logger)
      }
      logger.write_string("]")
    }
    Object(pairs) => {
      logger.write_string("{")
      for i, pair in pairs {
        if i > 0 {
          logger.write_string(",")
        }
        logger.write_string("\"")
        logger.write_string(pair.0)
        logger.write_string("\":")
        pair.1.output(logger)
      }
      logger.write_string("}")
    }
  }
}

///|
pub impl Eq for JsonValue with equal(self, other) {
  match (self, other) {
    (Null, Null) => true
    (Bool(a), Bool(b)) => a == b
    (Number(a), Number(b)) => a == b
    (Str(a), Str(b)) => a == b
    (Array(a), Array(b)) => a == b
    (Object(a), Object(b)) => {
      if a.length() != b.length() {
        return false
      }
      let mut i = 0
      while i < a.length() {
        if a[i].0 != b[i].0 || a[i].1 != b[i].1 {
          return false
        }
        i = i + 1
      }
      true
    }
    _ => false
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

///|
/// Skip JSON whitespace (space, tab, newline, carriage return).
fn json_ws() -> @parsec.Parser[String] {
  @parsec.multispace0()
}

// ---------------------------------------------------------------------------
// String parsing
// ---------------------------------------------------------------------------

///|
/// Parses a single hex digit character and returns its numeric value.
fn hex_digit_value(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else {
    c.to_int() - 'A'.to_int() + 10
  }
}

///|
/// Parse exactly 4 hex digits and return the codepoint value (0–65535).
fn hex4() -> @parsec.Parser[Int] {
  @parsec.map(
    @parsec.take_while_m_n(4, 4, @parsec.is_hex_digit),
    fn(s) {
      let mut v = 0
      for c in s {
        v = v * 16 + hex_digit_value(c)
      }
      v
    },
  )
}

///|
/// Parse a JSON string escape sequence (the character after the leading `\`).
fn json_escape() -> @parsec.Parser[String] {
  @parsec.Parser::new(fn(input) {
    if input.length() == 0 {
      return Err(@parsec.ParseError::new(input, "expected escape sequence"))
    }
    match input.unsafe_char_at(0) {
      '"' => Ok((input.substring(start=1), "\""))
      '\\' => Ok((input.substring(start=1), "\\"))
      '/' => Ok((input.substring(start=1), "/"))
      'b' => Ok((input.substring(start=1), "\b"))
      'f' => Ok((input.substring(start=1), "\u{000C}"))
      'n' => Ok((input.substring(start=1), "\n"))
      'r' => Ok((input.substring(start=1), "\r"))
      't' => Ok((input.substring(start=1), "\t"))
      'u' =>
        match hex4().parse(input.substring(start=1)) {
          Ok((rest, cp)) =>
            Ok((rest, String::make(1, cp.unsafe_to_char())))
          Err(e) => Err(e)
        }
      c =>
        Err(
          @parsec.ParseError::new(
            input,
            "unknown escape '\\" + String::make(1, c) + "'",
          ),
        )
    }
  })
}

///|
/// Parse the contents of a JSON string (between the outer quotes).
/// Called after the opening `"` has been consumed.
fn json_string_inner() -> @parsec.Parser[String] {
  @parsec.Parser::new(fn(input) {
    let buf = StringBuilder::new()
    let mut rest = input
    while true {
      if rest.length() == 0 {
        return Err(@parsec.ParseError::new(input, "unterminated string"))
      }
      let c = rest.unsafe_char_at(0)
      if c == '"' {
        // end of string — consume the closing quote
        return Ok((rest.substring(start=1), buf.to_string()))
      } else if c == '\\' {
        match json_escape().parse(rest.substring(start=1)) {
          Ok((rest2, escaped)) => {
            buf.write_string(escaped)
            rest = rest2
          }
          Err(e) => return Err(e)
        }
      } else if c.to_int() < 0x20 {
        return Err(
          @parsec.ParseError::new(
            rest,
            "unescaped control character in string",
          ),
        )
      } else {
        buf.write_char(c)
        rest = rest.substring(start=1)
      }
    }
    // unreachable — loop always returns
    Err(@parsec.ParseError::new(input, "unterminated string"))
  })
}

///|
/// Parse a JSON string value (including the surrounding quotes).
fn json_string_parser() -> @parsec.Parser[String] {
  @parsec.preceded(@parsec.char_('"'), json_string_inner())
}

// ---------------------------------------------------------------------------
// Value parser (recursive via lazily-evaluated function reference)
// ---------------------------------------------------------------------------

///|
/// Parse a JSON value.
pub fn parse_value() -> @parsec.Parser[JsonValue] {
  @parsec.Parser::new(fn(input) { parse_value_impl(input) })
}

///|
fn parse_value_impl(input : String) -> @parsec.IResult[JsonValue] {
  // skip leading whitespace
  let input = match json_ws().parse(input) {
    Ok((rest, _)) => rest
    Err(_) => input
  }
  if input.length() == 0 {
    return Err(@parsec.ParseError::new(input, "unexpected end of input"))
  }
  match input.unsafe_char_at(0) {
    '"' =>
      match json_string_parser().parse(input) {
        Ok((rest, s)) => Ok((rest, Str(s)))
        Err(e) => Err(e)
      }
    '[' => parse_array_impl(input)
    '{' => parse_object_impl(input)
    't' =>
      match @parsec.tag("true").parse(input) {
        Ok((rest, _)) => Ok((rest, Bool(true)))
        Err(e) => Err(e)
      }
    'f' =>
      match @parsec.tag("false").parse(input) {
        Ok((rest, _)) => Ok((rest, Bool(false)))
        Err(e) => Err(e)
      }
    'n' =>
      match @parsec.tag("null").parse(input) {
        Ok((rest, _)) => Ok((rest, Null))
        Err(e) => Err(e)
      }
    _ =>
      match @parsec.double().parse(input) {
        Ok((rest, n)) => Ok((rest, Number(n)))
        Err(_) =>
          Err(
            @parsec.ParseError::new(
              input,
              "unexpected character '" +
              String::make(1, input.unsafe_char_at(0)) +
              "'",
            ),
          )
      }
  }
}

///|
fn parse_array_impl(input : String) -> @parsec.IResult[JsonValue] {
  // consume '['
  let rest = match @parsec.char_('[').parse(input) {
    Ok((r, _)) => r
    Err(e) => return Err(e)
  }
  // skip whitespace
  let rest = match json_ws().parse(rest) {
    Ok((r, _)) => r
    Err(_) => rest
  }
  // empty array?
  if rest.length() > 0 && rest.unsafe_char_at(0) == ']' {
    return Ok((rest.substring(start=1), Array([])))
  }
  let items : Array[JsonValue] = []
  // parse first element
  let rest = match parse_value_impl(rest) {
    Ok((r, v)) => {
      items.push(v)
      r
    }
    Err(e) => return Err(e)
  }
  let mut remaining = rest
  // parse remaining elements
  while true {
    let r = match json_ws().parse(remaining) {
      Ok((r2, _)) => r2
      Err(_) => remaining
    }
    if r.length() == 0 {
      return Err(@parsec.ParseError::new(r, "unclosed array"))
    }
    if r.unsafe_char_at(0) == ']' {
      remaining = r.substring(start=1)
      break
    }
    if r.unsafe_char_at(0) != ',' {
      return Err(
        @parsec.ParseError::new(r, "expected ',' or ']' in array"),
      )
    }
    let after_comma = r.substring(start=1)
    match parse_value_impl(after_comma) {
      Ok((r2, v)) => {
        items.push(v)
        remaining = r2
      }
      Err(e) => return Err(e)
    }
  }
  Ok((remaining, Array(items)))
}

///|
fn parse_object_impl(input : String) -> @parsec.IResult[JsonValue] {
  // consume '{'
  let rest = match @parsec.char_('{').parse(input) {
    Ok((r, _)) => r
    Err(e) => return Err(e)
  }
  let rest = match json_ws().parse(rest) {
    Ok((r, _)) => r
    Err(_) => rest
  }
  // empty object?
  if rest.length() > 0 && rest.unsafe_char_at(0) == '}' {
    return Ok((rest.substring(start=1), Object([])))
  }
  let pairs : Array[(String, JsonValue)] = []
  // parse first key-value pair
  let rest = match parse_kv_pair(rest) {
    Ok((r, kv)) => {
      pairs.push(kv)
      r
    }
    Err(e) => return Err(e)
  }
  let mut remaining = rest
  while true {
    let r = match json_ws().parse(remaining) {
      Ok((r2, _)) => r2
      Err(_) => remaining
    }
    if r.length() == 0 {
      return Err(@parsec.ParseError::new(r, "unclosed object"))
    }
    if r.unsafe_char_at(0) == '}' {
      remaining = r.substring(start=1)
      break
    }
    if r.unsafe_char_at(0) != ',' {
      return Err(
        @parsec.ParseError::new(r, "expected ',' or '}' in object"),
      )
    }
    let after_comma = r.substring(start=1)
    match parse_kv_pair(after_comma) {
      Ok((r2, kv)) => {
        pairs.push(kv)
        remaining = r2
      }
      Err(e) => return Err(e)
    }
  }
  Ok((remaining, Object(pairs)))
}

///|
fn parse_kv_pair(
  input : String
) -> @parsec.IResult[(String, JsonValue)] {
  let input = match json_ws().parse(input) {
    Ok((r, _)) => r
    Err(_) => input
  }
  let (rest, key) = match json_string_parser().parse(input) {
    Ok(r) => r
    Err(e) => return Err(e)
  }
  let rest = match json_ws().parse(rest) {
    Ok((r, _)) => r
    Err(_) => rest
  }
  let rest = match @parsec.char_(':').parse(rest) {
    Ok((r, _)) => r
    Err(e) => return Err(e)
  }
  match parse_value_impl(rest) {
    Ok((r, v)) => Ok((r, (key, v)))
    Err(e) => Err(e)
  }
}

///|
/// Parse a complete JSON text (a single JSON value).
///
/// Returns `Ok(JsonValue)` or `Err(ParseError)`.
pub fn parse(input : String) -> Result[JsonValue, @parsec.ParseError] {
  match parse_value().parse(input) {
    Ok((rest, value)) => {
      // Ensure all input was consumed (ignoring trailing whitespace)
      let rest = match json_ws().parse(rest) {
        Ok((r, _)) => r
        Err(_) => rest
      }
      if rest.length() > 0 {
        Err(@parsec.ParseError::new(rest, "unexpected trailing input"))
      } else {
        Ok(value)
      }
    }
    Err(e) => Err(e)
  }
}
