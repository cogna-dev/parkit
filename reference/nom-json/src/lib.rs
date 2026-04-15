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

//! Reference JSON parser built with Rust nom.
//!
//! This implementation mirrors the MoonBit `cogna-dev/parskit/json` parser,
//! so we can cross-check that both produce identical results for the same input.

use nom::{
    branch::alt,
    bytes::complete::{tag, take_while, take_while_m_n},
    character::complete::{char, multispace0},
    combinator::{map, map_res, opt, value},
    multi::separated_list0,
    sequence::{delimited, preceded, separated_pair, terminated},
    IResult, Parser,
};

/// A JSON value, matching ECMA-404 / the MoonBit `JsonValue` enum.
#[derive(Debug, Clone, PartialEq)]
pub enum JsonValue {
    Null,
    Bool(bool),
    Number(f64),
    Str(String),
    Array(Vec<JsonValue>),
    Object(Vec<(String, JsonValue)>),
}

// ---------------------------------------------------------------------------
// Whitespace
// ---------------------------------------------------------------------------

fn ws<'a, F, O>(inner: F) -> impl Parser<&'a str, Output = O, Error = nom::error::Error<&'a str>>
where
    F: Parser<&'a str, Output = O, Error = nom::error::Error<&'a str>>,
{
    delimited(multispace0, inner, multispace0)
}

// ---------------------------------------------------------------------------
// String parsing
// ---------------------------------------------------------------------------

fn hex_char(input: &str) -> IResult<&str, char> {
    map_res(
        take_while_m_n(4, 4, |c: char| c.is_ascii_hexdigit()),
        |s: &str| {
            u32::from_str_radix(s, 16)
                .ok()
                .and_then(char::from_u32)
                .ok_or("invalid unicode escape")
        },
    )
    .parse(input)
}

fn escape_sequence(input: &str) -> IResult<&str, String> {
    preceded(
        char('\\'),
        alt((
            value("\"".to_string(), char('"')),
            value("\\".to_string(), char('\\')),
            value("/".to_string(), char('/')),
            value("\x08".to_string(), char('b')),
            value("\x0C".to_string(), char('f')),
            value("\n".to_string(), char('n')),
            value("\r".to_string(), char('r')),
            value("\t".to_string(), char('t')),
            map(preceded(char('u'), hex_char), |c| c.to_string()),
        )),
    )
    .parse(input)
}

fn string_inner(input: &str) -> IResult<&str, String> {
    let mut result = String::new();
    let mut remaining = input;

    loop {
        // Take a run of normal characters (not '"' and not '\')
        let (rest, chunk) = take_while(|c: char| c != '"' && c != '\\').parse(remaining)?;
        result.push_str(chunk);
        remaining = rest;

        if remaining.starts_with('"') {
            // End of string (caller handles the closing quote)
            return Ok((remaining, result));
        } else if remaining.starts_with('\\') {
            let (rest2, escaped) = escape_sequence(remaining)?;
            result.push_str(&escaped);
            remaining = rest2;
        } else {
            return Err(nom::Err::Error(nom::error::Error::new(
                remaining,
                nom::error::ErrorKind::Char,
            )));
        }
    }
}

fn json_string(input: &str) -> IResult<&str, String> {
    delimited(char('"'), string_inner, char('"')).parse(input)
}

// ---------------------------------------------------------------------------
// Number parsing
// ---------------------------------------------------------------------------

fn json_number(input: &str) -> IResult<&str, f64> {
    map_res(
        nom::bytes::complete::take_while1(|c: char| {
            c.is_ascii_digit() || c == '-' || c == '.' || c == 'e' || c == 'E' || c == '+'
        }),
        |s: &str| s.parse::<f64>(),
    )
    .parse(input)
}

// ---------------------------------------------------------------------------
// Value parser (recursive)
// ---------------------------------------------------------------------------

fn json_value(input: &str) -> IResult<&str, JsonValue> {
    ws(alt((
        value(JsonValue::Null, tag("null")),
        value(JsonValue::Bool(true), tag("true")),
        value(JsonValue::Bool(false), tag("false")),
        map(json_string, JsonValue::Str),
        map(json_array, JsonValue::Array),
        map(json_object, JsonValue::Object),
        map(json_number, JsonValue::Number),
    )))
    .parse(input)
}

fn json_array(input: &str) -> IResult<&str, Vec<JsonValue>> {
    delimited(
        ws(char('[')),
        separated_list0(ws(char(',')), json_value),
        ws(char(']')),
    )
    .parse(input)
}

fn json_kv(input: &str) -> IResult<&str, (String, JsonValue)> {
    separated_pair(
        ws(json_string),
        ws(char(':')),
        json_value,
    )
    .parse(input)
}

fn json_object(input: &str) -> IResult<&str, Vec<(String, JsonValue)>> {
    delimited(
        ws(char('{')),
        separated_list0(ws(char(',')), json_kv),
        ws(char('}')),
    )
    .parse(input)
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Parse a complete JSON text.
///
/// Returns `Ok(JsonValue)` on success, `Err(String)` describing the failure.
pub fn parse(input: &str) -> Result<JsonValue, String> {
    match terminated(json_value, opt(multispace0)).parse(input) {
        Ok(("", value)) => Ok(value),
        Ok((rest, _)) => Err(format!("unexpected trailing input: {:?}", rest)),
        Err(e) => Err(format!("parse error: {}", e)),
    }
}

// ---------------------------------------------------------------------------
// Tests — these cross-validate against the MoonBit json_test.mbt suite
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    // ── same cases as src/json/json_test.mbt ──────────────────────────────

    #[test]
    fn test_parse_null() {
        assert_eq!(parse("null"), Ok(JsonValue::Null));
    }

    #[test]
    fn test_parse_true() {
        assert_eq!(parse("true"), Ok(JsonValue::Bool(true)));
    }

    #[test]
    fn test_parse_false() {
        assert_eq!(parse("false"), Ok(JsonValue::Bool(false)));
    }

    #[test]
    fn test_parse_integer_number() {
        match parse("42") {
            Ok(JsonValue::Number(n)) => assert!((n - 42.0).abs() < 1e-10),
            other => panic!("expected Number(42), got {:?}", other),
        }
    }

    #[test]
    fn test_parse_negative_number() {
        match parse("-3.14") {
            Ok(JsonValue::Number(n)) => assert!((n + 3.14).abs() < 1e-10),
            other => panic!("expected Number(-3.14), got {:?}", other),
        }
    }

    #[test]
    fn test_parse_simple_string() {
        assert_eq!(parse(r#""hello""#), Ok(JsonValue::Str("hello".to_string())));
    }

    #[test]
    fn test_parse_string_with_escape() {
        assert_eq!(
            parse(r#""hello\nworld""#),
            Ok(JsonValue::Str("hello\nworld".to_string()))
        );
    }

    #[test]
    fn test_parse_string_with_unicode_escape() {
        assert_eq!(
            parse(r#""\u0041""#),
            Ok(JsonValue::Str("A".to_string()))
        );
    }

    #[test]
    fn test_parse_empty_array() {
        assert_eq!(parse("[]"), Ok(JsonValue::Array(vec![])));
    }

    #[test]
    fn test_parse_array_of_numbers() {
        match parse("[1, 2, 3]") {
            Ok(JsonValue::Array(arr)) => {
                assert_eq!(arr.len(), 3);
                assert!(matches!(arr[0], JsonValue::Number(n) if (n - 1.0).abs() < 1e-10));
            }
            other => panic!("expected array, got {:?}", other),
        }
    }

    #[test]
    fn test_parse_empty_object() {
        assert_eq!(parse("{}"), Ok(JsonValue::Object(vec![])));
    }

    #[test]
    fn test_parse_simple_object() {
        match parse(r#"{"key": "value"}"#) {
            Ok(JsonValue::Object(pairs)) => {
                assert_eq!(pairs.len(), 1);
                assert_eq!(pairs[0].0, "key");
                assert_eq!(pairs[0].1, JsonValue::Str("value".to_string()));
            }
            other => panic!("expected object, got {:?}", other),
        }
    }

    #[test]
    fn test_parse_nested_object() {
        let input = r#"{"name": "Alice", "age": 30, "scores": [95, 87, 92]}"#;
        match parse(input) {
            Ok(JsonValue::Object(pairs)) => {
                assert_eq!(pairs.len(), 3);
                assert_eq!(pairs[0].0, "name");
                assert_eq!(pairs[0].1, JsonValue::Str("Alice".to_string()));
            }
            other => panic!("expected object, got {:?}", other),
        }
    }

    #[test]
    fn test_parse_whitespace_around_values() {
        assert_eq!(parse("  null  "), Ok(JsonValue::Null));
        assert_eq!(parse("  true  "), Ok(JsonValue::Bool(true)));
    }

    #[test]
    fn test_parse_trailing_input_fails() {
        assert!(parse("null extra").is_err());
    }

    #[test]
    fn test_parse_empty_input_fails() {
        assert!(parse("").is_err());
    }

    #[test]
    fn test_parse_complex_nested_structure() {
        let input = r#"{
  "name": "JSON Test",
  "version": 1,
  "features": ["parsing", "combinators"],
  "nested": {
    "a": true,
    "b": null,
    "c": -1.5e2
  }
}"#;
        match parse(input) {
            Ok(JsonValue::Object(pairs)) => assert_eq!(pairs.len(), 4),
            other => panic!("expected object with 4 pairs, got {:?}", other),
        }
    }

    /// Validates the same benchmark payload used in src/benchmark/bench.mbt.
    #[test]
    fn test_parse_benchmark_payload() {
        let input = r#"[
  {
    "id": 1,
    "name": "Alice",
    "email": "alice@example.com",
    "active": true,
    "score": 98.6,
    "tags": ["admin", "user"],
    "address": {
      "street": "123 Main St",
      "city": "Springfield",
      "zip": "62701"
    }
  },
  {
    "id": 2,
    "name": "Bob",
    "email": "bob@example.com",
    "active": false,
    "score": 74.2,
    "tags": ["user"],
    "address": {
      "street": "456 Elm Ave",
      "city": "Shelbyville",
      "zip": "62565"
    }
  },
  {
    "id": 3,
    "name": "Carol",
    "email": "carol@example.com",
    "active": true,
    "score": 88.0,
    "tags": ["moderator", "user"],
    "address": {
      "street": "789 Oak Blvd",
      "city": "Capital City",
      "zip": "62702"
    }
  }
]"#;
        match parse(input) {
            Ok(JsonValue::Array(arr)) => {
                assert_eq!(arr.len(), 3);
                // Check first element
                match &arr[0] {
                    JsonValue::Object(pairs) => {
                        assert_eq!(pairs.len(), 7);
                        assert_eq!(pairs[1].0, "name");
                        assert_eq!(pairs[1].1, JsonValue::Str("Alice".to_string()));
                        assert_eq!(pairs[3].0, "active");
                        assert_eq!(pairs[3].1, JsonValue::Bool(true));
                    }
                    other => panic!("expected object, got {:?}", other),
                }
            }
            other => panic!("expected array of 3 objects, got {:?}", other),
        }
    }
}
