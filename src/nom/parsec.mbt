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
/// Error produced by a parser when it fails.
/// Holds the remaining input at the point of failure and a descriptive message.
pub struct ParseError {
  /// The remaining (unconsumed) input when the error occurred.
  pub input : String
  /// Human-readable description of what went wrong.
  pub message : String
}

///|
pub fn ParseError::new(input : String, message : String) -> ParseError {
  { input, message }
}

///|
pub impl Show for ParseError with output(self, logger) {
  logger.write_string("ParseError { input: \"")
  logger.write_string(self.input)
  logger.write_string("\", message: \"")
  logger.write_string(self.message)
  logger.write_string("\" }")
}

///|
pub impl Eq for ParseError with equal(self, other) {
  self.input == other.input && self.message == other.message
}

///|
/// The result type for a parser.
///
/// On success: `Ok((remaining_input, parsed_value))`
/// On failure: `Err(ParseError)`
///
/// This mirrors nom's `IResult<I, O, E>` with `I = String`, `E = ParseError`.
pub type IResult[O] = Result[(String, O), ParseError]

///|
/// Internal helper: convert an ASCII digit char to its numeric value.
fn digit_value(c : Char) -> Int {
  c.to_int() - '0'.to_int()
}

///|
/// A parser combinator. Wraps a function that consumes a `String` input
/// and returns an `IResult[O]`.
///
/// This mirrors the nom `Parser` trait: any function `(String) -> IResult[O]`
/// can be used as a parser.
pub struct Parser[O] {
  priv run : (String) -> IResult[O]
}

///|
/// Create a `Parser` from a plain function.
pub fn Parser::new[O](f : (String) -> IResult[O]) -> Parser[O] {
  { run: f }
}

///|
/// Run a parser on the given input, returning an `IResult`.
pub fn Parser::parse[O](self : Parser[O], input : String) -> IResult[O] {
  (self.run)(input)
}

// ---------------------------------------------------------------------------
// Character / byte predicates
// ---------------------------------------------------------------------------

///|
/// Matches the exact literal string `tag_str`.
///
/// Equivalent to nom's `tag`.
///
/// ## Example
/// ```moonbit
/// let p = @parsec.tag("hello")
/// assert_eq!(p.parse("hello world"), Ok((" world", "hello")))
/// ```
pub fn tag(tag_str : String) -> Parser[String] {
  Parser::new(fn(input) {
    let tlen = tag_str.length()
    if input.length() >= tlen && input[0:tlen] == tag_str {
      Ok((input[tlen:].to_string(), tag_str))
    } else {
      Err(ParseError::new(input, "expected \"" + tag_str + "\""))
    }
  })
}

///|
/// Matches a single character that satisfies the predicate `pred`.
///
/// Equivalent to nom's `satisfy`.
pub fn satisfy(pred : (Char) -> Bool) -> Parser[Char] {
  Parser::new(fn(input) {
    if input.length() == 0 {
      return Err(ParseError::new(input, "unexpected end of input"))
    }
    let c = input.get_char(0).unwrap()
    if pred(c) {
      Ok((input[1:].to_string(), c))
    } else {
      Err(
        ParseError::new(
          input,
          "character '" + String::make(1, c) + "' did not satisfy predicate",
        ),
      )
    }
  })
}

///|
/// Matches a single specific character.
///
/// Equivalent to nom's `char`.
pub fn char_(c : Char) -> Parser[Char] {
  satisfy(fn(x) { x == c })
}

///|
/// Matches any single character.
pub fn any_char() -> Parser[Char] {
  satisfy(fn(_) { true })
}

///|
/// Takes characters while `pred` returns `true`, returning the matched slice.
/// Returns an empty string if no characters match (always succeeds).
///
/// Equivalent to nom's `take_while`.
pub fn take_while(pred : (Char) -> Bool) -> Parser[String] {
  Parser::new(fn(input) {
    let mut end = 0
    let len = input.length()
    while end < len && pred(input.get_char(end).unwrap()) {
      end = end + 1
    }
    Ok((input[end:].to_string(), input[0:end].to_string()))
  })
}

///|
/// Like `take_while` but requires at least one matching character.
///
/// Equivalent to nom's `take_while1`.
pub fn take_while1(pred : (Char) -> Bool) -> Parser[String] {
  Parser::new(fn(input) {
    if input.length() == 0 || !pred(input.get_char(0).unwrap()) {
      return Err(ParseError::new(input, "take_while1: no matching characters"))
    }
    let mut end = 1
    let len = input.length()
    while end < len && pred(input.get_char(end).unwrap()) {
      end = end + 1
    }
    Ok((input[end:].to_string(), input[0:end].to_string()))
  })
}

///|
/// Takes exactly `n` characters.
///
/// Equivalent to nom's `take`.
pub fn take(n : Int) -> Parser[String] {
  Parser::new(fn(input) {
    if input.length() < n {
      Err(
        ParseError::new(
          input,
          "take: needed " +
          n.to_string() +
          " chars but only " +
          input.length().to_string() +
          " remain",
        ),
      )
    } else {
      Ok((input[n:].to_string(), input[0:n].to_string()))
    }
  })
}

///|
/// Takes `n` to `m` characters while `pred` is satisfied.
///
/// Equivalent to nom's `take_while_m_n`.
pub fn take_while_m_n(
  m : Int,
  n : Int,
  pred : (Char) -> Bool
) -> Parser[String] {
  Parser::new(fn(input) {
    let len = input.length()
    let mut end = 0
    while end < len && end < n && pred(input.get_char(end).unwrap()) {
      end = end + 1
    }
    if end < m {
      Err(
        ParseError::new(
          input,
          "take_while_m_n: matched " +
          end.to_string() +
          " chars but need at least " +
          m.to_string(),
        ),
      )
    } else {
      Ok((input[end:].to_string(), input[0:end].to_string()))
    }
  })
}

// ---------------------------------------------------------------------------
// Combinators
// ---------------------------------------------------------------------------

///|
/// Maps the output of a parser through a function.
///
/// Equivalent to nom's `map`.
pub fn map[A, B](parser : Parser[A], f : (A) -> B) -> Parser[B] {
  Parser::new(fn(input) {
    match parser.parse(input) {
      Ok((rest, value)) => Ok((rest, f(value)))
      Err(e) => Err(e)
    }
  })
}

///|
/// Maps the output of a parser through a fallible function.
/// If the function returns `Err`, the whole parser fails.
///
/// Equivalent to nom's `map_res`.
pub fn map_res[A, B, E : Show](
  parser : Parser[A],
  f : (A) -> Result[B, E]
) -> Parser[B] {
  Parser::new(fn(input) {
    match parser.parse(input) {
      Ok((rest, value)) =>
        match f(value) {
          Ok(b) => Ok((rest, b))
          Err(e) =>
            Err(ParseError::new(input, "map_res: " + e.to_string()))
        }
      Err(e) => Err(e)
    }
  })
}

///|
/// Tries parsers in order and returns the result of the first that succeeds.
///
/// Equivalent to nom's `alt`.
pub fn alt[O](parsers : Array[Parser[O]]) -> Parser[O] {
  Parser::new(fn(input) {
    let mut last_err : ParseError = ParseError::new(input, "alt: no alternatives")
    for p in parsers {
      match p.parse(input) {
        Ok(r) => return Ok(r)
        Err(e) => last_err = e
      }
    }
    Err(last_err)
  })
}

///|
/// Applies two parsers sequentially and returns a tuple of their outputs.
///
/// Equivalent to nom's `pair`.
pub fn pair[A, B](first : Parser[A], second : Parser[B]) -> Parser[(A, B)] {
  Parser::new(fn(input) {
    match first.parse(input) {
      Ok((rest1, a)) =>
        match second.parse(rest1) {
          Ok((rest2, b)) => Ok((rest2, (a, b)))
          Err(e) => Err(e)
        }
      Err(e) => Err(e)
    }
  })
}

///|
/// Applies three parsers and returns a tuple of their outputs.
pub fn tuple3[A, B, C](
  pa : Parser[A],
  pb : Parser[B],
  pc : Parser[C]
) -> Parser[(A, B, C)] {
  Parser::new(fn(input) {
    match pa.parse(input) {
      Ok((r1, a)) =>
        match pb.parse(r1) {
          Ok((r2, b)) =>
            match pc.parse(r2) {
              Ok((r3, c)) => Ok((r3, (a, b, c)))
              Err(e) => Err(e)
            }
          Err(e) => Err(e)
        }
      Err(e) => Err(e)
    }
  })
}

///|
/// Applies the first parser, discards its output, applies the second,
/// and returns the second parser's output.
///
/// Equivalent to nom's `preceded`.
pub fn preceded[A, B](discard : Parser[A], keep : Parser[B]) -> Parser[B] {
  Parser::new(fn(input) {
    match discard.parse(input) {
      Ok((rest, _)) => keep.parse(rest)
      Err(e) => Err(e)
    }
  })
}

///|
/// Applies the first parser, then the second (discarding its output),
/// and returns the first parser's output.
///
/// Equivalent to nom's `terminated`.
pub fn terminated[A, B](keep : Parser[A], discard : Parser[B]) -> Parser[A] {
  Parser::new(fn(input) {
    match keep.parse(input) {
      Ok((rest1, a)) =>
        match discard.parse(rest1) {
          Ok((rest2, _)) => Ok((rest2, a))
          Err(e) => Err(e)
        }
      Err(e) => Err(e)
    }
  })
}

///|
/// Matches `open`, then `parser`, then `close`, returning only the middle.
///
/// Equivalent to nom's `delimited`.
pub fn delimited[A, B, C](
  open : Parser[A],
  parser : Parser[B],
  close : Parser[C]
) -> Parser[B] {
  preceded(open, terminated(parser, close))
}

///|
/// Runs `parser` zero or more times, collecting results into an array.
///
/// Equivalent to nom's `many0`.
pub fn many0[O](parser : Parser[O]) -> Parser[Array[O]] {
  Parser::new(fn(input) {
    let results : Array[O] = []
    let mut remaining = input
    while true {
      match parser.parse(remaining) {
        Ok((rest, value)) => {
          results.push(value)
          remaining = rest
        }
        Err(_) => break
      }
    }
    Ok((remaining, results))
  })
}

///|
/// Runs `parser` one or more times, collecting results into an array.
///
/// Equivalent to nom's `many1`.
pub fn many1[O](parser : Parser[O]) -> Parser[Array[O]] {
  Parser::new(fn(input) {
    match parser.parse(input) {
      Err(e) => Err(e)
      Ok((rest, first)) => {
        let results : Array[O] = [first]
        let mut remaining = rest
        while true {
          match parser.parse(remaining) {
            Ok((rest2, value)) => {
              results.push(value)
              remaining = rest2
            }
            Err(_) => break
          }
        }
        Ok((remaining, results))
      }
    }
  })
}

///|
/// Runs `parser` zero or more times separated by `sep`, collecting results.
///
/// Equivalent to nom's `separated_list0`.
pub fn separated_list0[O, S](
  sep : Parser[S],
  parser : Parser[O]
) -> Parser[Array[O]] {
  Parser::new(fn(input) {
    let results : Array[O] = []
    match parser.parse(input) {
      Err(_) => Ok((input, results))
      Ok((rest, first)) => {
        results.push(first)
        let mut remaining = rest
        while true {
          match sep.parse(remaining) {
            Err(_) => break
            Ok((rest2, _)) =>
              match parser.parse(rest2) {
                Err(_) => break
                Ok((rest3, value)) => {
                  results.push(value)
                  remaining = rest3
                }
              }
          }
        }
        Ok((remaining, results))
      }
    }
  })
}

///|
/// Runs `parser` one or more times separated by `sep`, collecting results.
///
/// Equivalent to nom's `separated_list1`.
pub fn separated_list1[O, S](
  sep : Parser[S],
  parser : Parser[O]
) -> Parser[Array[O]] {
  Parser::new(fn(input) {
    match parser.parse(input) {
      Err(e) => Err(e)
      Ok((rest, first)) => {
        let results : Array[O] = [first]
        let mut remaining = rest
        while true {
          match sep.parse(remaining) {
            Err(_) => break
            Ok((rest2, _)) =>
              match parser.parse(rest2) {
                Err(_) => break
                Ok((rest3, value)) => {
                  results.push(value)
                  remaining = rest3
                }
              }
          }
        }
        Ok((remaining, results))
      }
    }
  })
}

///|
/// Makes a parser optional: returns `Some(value)` on success or `None` on failure.
///
/// Equivalent to nom's `opt`.
pub fn opt[O](parser : Parser[O]) -> Parser[O?] {
  Parser::new(fn(input) {
    match parser.parse(input) {
      Ok((rest, value)) => Ok((rest, Some(value)))
      Err(_) => Ok((input, None))
    }
  })
}

///|
/// Applies `parser` and verifies its output satisfies `pred`.
/// If not, returns an error without consuming input.
///
/// Equivalent to nom's `verify`.
pub fn verify[O](parser : Parser[O], pred : (O) -> Bool) -> Parser[O] {
  Parser::new(fn(input) {
    match parser.parse(input) {
      Ok((rest, value)) =>
        if pred(value) {
          Ok((rest, value))
        } else {
          Err(ParseError::new(input, "verify: predicate failed"))
        }
      Err(e) => Err(e)
    }
  })
}

///|
/// Returns a parser that always succeeds with the given value without
/// consuming any input.
///
/// Equivalent to nom's `success`.
pub fn success[O](value : O) -> Parser[O] {
  Parser::new(fn(input) { Ok((input, value)) })
}

///|
/// Returns a parser that always fails with the given message.
///
/// Equivalent to nom's `fail`.
pub fn fail[O](message : String) -> Parser[O] {
  Parser::new(fn(input) { Err(ParseError::new(input, message)) })
}

///|
/// Returns a parser that matches end-of-input.
///
/// Equivalent to nom's `eof`.
pub fn eof() -> Parser[String] {
  Parser::new(fn(input) {
    if input.length() == 0 {
      Ok(("", ""))
    } else {
      Err(ParseError::new(input, "expected end of input"))
    }
  })
}

///|
/// Wraps a parser with an additional error context message.
///
/// Equivalent to nom's `context`.
pub fn context[O](ctx : String, parser : Parser[O]) -> Parser[O] {
  Parser::new(fn(input) {
    match parser.parse(input) {
      Ok(r) => Ok(r)
      Err(e) => Err(ParseError::new(e.input, ctx + ": " + e.message))
    }
  })
}

// ---------------------------------------------------------------------------
// Whitespace helpers
// ---------------------------------------------------------------------------

///|
/// Returns true if the character is ASCII whitespace.
pub fn is_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
/// Matches zero or more whitespace characters.
///
/// Equivalent to nom's `multispace0`.
pub fn multispace0() -> Parser[String] {
  take_while(is_whitespace)
}

///|
/// Matches one or more whitespace characters.
///
/// Equivalent to nom's `multispace1`.
pub fn multispace1() -> Parser[String] {
  take_while1(is_whitespace)
}

///|
/// Wraps `parser`, consuming any leading whitespace before it.
pub fn ws[O](parser : Parser[O]) -> Parser[O] {
  preceded(multispace0(), parser)
}

// ---------------------------------------------------------------------------
// Numeric helpers
// ---------------------------------------------------------------------------

///|
/// Returns true if the character is an ASCII decimal digit.
pub fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
/// Returns true if the character is an ASCII hexadecimal digit.
pub fn is_hex_digit(c : Char) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
/// Returns true if the character is an ASCII letter.
pub fn is_alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
/// Returns true if the character is an ASCII letter or digit.
pub fn is_alphanumeric(c : Char) -> Bool {
  is_alpha(c) || is_digit(c)
}

///|
/// Parses one or more ASCII decimal digits, returning the matched string.
///
/// Equivalent to nom's `digit1`.
pub fn digit1() -> Parser[String] {
  take_while1(is_digit)
}

///|
/// Parses zero or more ASCII decimal digits, returning the matched string.
///
/// Equivalent to nom's `digit0`.
pub fn digit0() -> Parser[String] {
  take_while(is_digit)
}

///|
/// Convert a decimal digit string to an `Int`. Assumes all chars are digits.
fn digits_to_int(s : String) -> Int {
  let mut result = 0
  for c in s {
    result = result * 10 + digit_value(c)
  }
  result
}

///|
/// Parses a non-negative integer in decimal notation.
pub fn uint() -> Parser[Int] {
  map(digit1(), digits_to_int)
}

///|
/// Parses a signed integer (optional leading `-`) in decimal notation.
pub fn int() -> Parser[Int] {
  Parser::new(fn(input) {
    let (rest, sign) = match char_('-').parse(input) {
      Ok((r, _)) => (r, -1)
      Err(_) => (input, 1)
    }
    match digit1().parse(rest) {
      Ok((rest2, digits)) => Ok((rest2, sign * digits_to_int(digits)))
      Err(e) => Err(e)
    }
  })
}

///|
/// Compute a double from its parsed parts.
/// Separating the computation avoids needing an external string-to-double API.
fn compute_double(
  sign : Double,
  int_str : String,
  frac_str : String,
  exp_sign : Int,
  exp_str : String
) -> Double {
  // Integer part
  let mut int_part = 0.0
  for c in int_str {
    int_part = int_part * 10.0 + digit_value(c).to_double()
  }
  // Fractional part
  let mut frac_part = 0.0
  let mut frac_div = 1.0
  for c in frac_str {
    frac_div = frac_div * 10.0
    frac_part = frac_part + digit_value(c).to_double() / frac_div
  }
  // Exponent
  let mut exp = 0
  for c in exp_str {
    exp = exp * 10 + digit_value(c)
  }
  let base = int_part + frac_part
  let result = if exp == 0 {
    base
  } else {
    let mut power = 1.0
    for _ in 0..<exp {
      power = power * 10.0
    }
    if exp_sign > 0 {
      base * power
    } else {
      base / power
    }
  }
  sign * result
}

///|
/// Parses a floating-point number (e.g. `3.14`, `-0.5`, `1e10`, `1.5e-3`).
///
/// Equivalent to nom's `double`.
pub fn double() -> Parser[Double] {
  Parser::new(fn(input) {
    let mut pos = 0
    let len = input.length()
    // optional minus
    let sign = if pos < len && input.get_char(pos).unwrap() == '-' {
      pos = pos + 1
      -1.0
    } else {
      1.0
    }
    // integer part (required)
    if pos >= len || !is_digit(input.get_char(pos).unwrap()) {
      return Err(ParseError::new(input, "double: expected digit"))
    }
    let int_start = pos
    while pos < len && is_digit(input.get_char(pos).unwrap()) {
      pos = pos + 1
    }
    let int_str = input[int_start:pos].to_string()
    // optional fractional part
    let frac_str = if pos < len && input.get_char(pos).unwrap() == '.' {
      pos = pos + 1
      if pos >= len || !is_digit(input.get_char(pos).unwrap()) {
        return Err(
          ParseError::new(input, "double: expected digit after decimal point"),
        )
      }
      let frac_start = pos
      while pos < len && is_digit(input.get_char(pos).unwrap()) {
        pos = pos + 1
      }
      input[frac_start:pos].to_string()
    } else {
      ""
    }
    // optional exponent
    let (exp_sign, exp_str) = if pos < len &&
      (input.get_char(pos).unwrap() == 'e' || input.get_char(pos).unwrap() == 'E') {
      pos = pos + 1
      let esign = if pos < len && input.get_char(pos).unwrap() == '+' {
        pos = pos + 1
        1
      } else if pos < len && input.get_char(pos).unwrap() == '-' {
        pos = pos + 1
        -1
      } else {
        1
      }
      if pos >= len || !is_digit(input.get_char(pos).unwrap()) {
        return Err(
          ParseError::new(input, "double: expected digit in exponent"),
        )
      }
      let exp_start = pos
      while pos < len && is_digit(input.get_char(pos).unwrap()) {
        pos = pos + 1
      }
      (esign, input[exp_start:pos].to_string())
    } else {
      (1, "")
    }
    let rest = input[pos:].to_string()
    Ok((rest, compute_double(sign, int_str, frac_str, exp_sign, exp_str)))
  })
}
