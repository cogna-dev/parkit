// Tests for the parsec library

///|
test "tag: match exact string" {
  let p = tag("hello")
  assert_eq!(p.parse("hello world"), Ok((" world", "hello")))
}

///|
test "tag: mismatch returns error" {
  let p = tag("hello")
  let result = p.parse("world")
  assert_eq!(result.is_err(), true)
}

///|
test "tag: empty input returns error" {
  let p = tag("hi")
  let result = p.parse("")
  assert_eq!(result.is_err(), true)
}

///|
test "satisfy: matching char" {
  let p = satisfy(is_digit)
  assert_eq!(p.parse("3abc"), Ok(("abc", '3')))
}

///|
test "satisfy: non-matching char" {
  let p = satisfy(is_digit)
  assert_eq!(p.parse("abc").is_err(), true)
}

///|
test "char_: exact char" {
  let p = char_('{')
  assert_eq!(p.parse("{body}"), Ok(("body}", '{')))
}

///|
test "take_while: zero match is ok" {
  let p = take_while(is_digit)
  assert_eq!(p.parse("abc"), Ok(("abc", "")))
}

///|
test "take_while: several matches" {
  let p = take_while(is_digit)
  assert_eq!(p.parse("123abc"), Ok(("abc", "123")))
}

///|
test "take_while1: at least one required" {
  let p = take_while1(is_digit)
  assert_eq!(p.parse("123abc"), Ok(("abc", "123")))
  assert_eq!(p.parse("abc").is_err(), true)
}

///|
test "take: exact count" {
  let p = take(3)
  assert_eq!(p.parse("hello"), Ok(("lo", "hel")))
}

///|
test "take: not enough input" {
  let p = take(10)
  assert_eq!(p.parse("hi").is_err(), true)
}

///|
test "take_while_m_n: basic usage" {
  let p = take_while_m_n(2, 4, is_digit)
  assert_eq!(p.parse("123abc"), Ok(("abc", "123")))
  assert_eq!(p.parse("1abc").is_err(), true)
}

///|
test "map: transforms output" {
  let p = map(digit1(), fn(s) { s.length() })
  assert_eq!(p.parse("123abc"), Ok(("abc", 3)))
}

///|
test "alt: first success wins" {
  let p = alt([tag("foo"), tag("bar"), tag("baz")])
  assert_eq!(p.parse("baz rest"), Ok((" rest", "baz")))
}

///|
test "alt: all fail returns error" {
  let p = alt([tag("foo"), tag("bar")])
  assert_eq!(p.parse("qux").is_err(), true)
}

///|
test "pair: two parsers in sequence" {
  let p = pair(tag("foo"), tag("bar"))
  assert_eq!(p.parse("foobar!"), Ok(("!", ("foo", "bar"))))
}

///|
test "preceded: discard prefix" {
  let p = preceded(tag("--"), digit1())
  assert_eq!(p.parse("--42rest"), Ok(("rest", "42")))
}

///|
test "terminated: discard suffix" {
  let p = terminated(digit1(), tag(";"))
  assert_eq!(p.parse("99;next"), Ok(("next", "99")))
}

///|
test "delimited: keep middle" {
  let p = delimited(tag("("), digit1(), tag(")"))
  assert_eq!(p.parse("(123)rest"), Ok(("rest", "123")))
}

///|
test "many0: zero matches" {
  let p = many0(tag("ab"))
  assert_eq!(p.parse("ccc"), Ok(("ccc", [])))
}

///|
test "many0: several matches" {
  let p = many0(tag("ab"))
  assert_eq!(p.parse("ababccc"), Ok(("ccc", ["ab", "ab"])))
}

///|
test "many1: at least one" {
  let p = many1(tag("ab"))
  assert_eq!(p.parse("ababccc"), Ok(("ccc", ["ab", "ab"])))
  assert_eq!(p.parse("ccc").is_err(), true)
}

///|
test "separated_list0: empty input ok" {
  let p = separated_list0(tag(","), digit1())
  assert_eq!(p.parse(""), Ok(("", [])))
}

///|
test "separated_list0: csv-like" {
  let p = separated_list0(tag(","), digit1())
  assert_eq!(p.parse("1,22,333 rest"), Ok((" rest", ["1", "22", "333"])))
}

///|
test "separated_list1: requires one" {
  let p = separated_list1(tag(","), digit1())
  assert_eq!(p.parse("abc").is_err(), true)
  assert_eq!(p.parse("1,2"), Ok(("", ["1", "2"])))
}

///|
test "opt: success" {
  let p = opt(tag("hello"))
  assert_eq!(p.parse("hello world"), Ok((" world", Some("hello"))))
}

///|
test "opt: failure returns None" {
  let p = opt(tag("hello"))
  assert_eq!(p.parse("world"), Ok(("world", None)))
}

///|
test "verify: passes predicate" {
  let p = verify(digit1(), fn(s) { s.length() > 1 })
  assert_eq!(p.parse("42abc"), Ok(("abc", "42")))
}

///|
test "verify: fails predicate" {
  let p = verify(digit1(), fn(s) { s.length() > 1 })
  assert_eq!(p.parse("1abc").is_err(), true)
}

///|
test "eof: matches empty input" {
  assert_eq!(eof().parse(""), Ok(("", "")))
  assert_eq!(eof().parse("x").is_err(), true)
}

///|
test "ws: skips leading whitespace" {
  let p = ws(tag("hello"))
  assert_eq!(p.parse("   hello world"), Ok((" world", "hello")))
  assert_eq!(p.parse("hello"), Ok(("", "hello")))
}

///|
test "multispace0: matches whitespace" {
  assert_eq!(multispace0().parse("   abc"), Ok(("abc", "   ")))
  assert_eq!(multispace0().parse("abc"), Ok(("abc", "")))
}

///|
test "multispace1: requires whitespace" {
  assert_eq!(multispace1().parse("   abc"), Ok(("abc", "   ")))
  assert_eq!(multispace1().parse("abc").is_err(), true)
}

///|
test "digit1: basic" {
  assert_eq!(digit1().parse("007bond"), Ok(("bond", "007")))
}

///|
test "uint: parses unsigned integer" {
  assert_eq!(uint().parse("42rest"), Ok(("rest", 42)))
}

///|
test "int: parses signed integer" {
  assert_eq!(int().parse("-7rest"), Ok(("rest", -7)))
  assert_eq!(int().parse("42rest"), Ok(("rest", 42)))
}

///|
test "double: parses float" {
  let result = double().parse("3.14rest")
  match result {
    Ok((rest, d)) => {
      assert_eq!(rest, "rest")
      assert_eq!((d - 3.14).abs() < 1.0e-10, true)
    }
    Err(_) => abort("expected Ok")
  }
}

///|
test "double: scientific notation" {
  let result = double().parse("1.5e2rest")
  match result {
    Ok((rest, d)) => {
      assert_eq!(rest, "rest")
      assert_eq!((d - 150.0).abs() < 1.0e-6, true)
    }
    Err(_) => abort("expected Ok")
  }
}

///|
test "context: error message contains context" {
  let p = context("my_parser", tag("hello"))
  match p.parse("world") {
    Err(e) => assert_eq!(e.message.starts_with("my_parser:"), true)
    Ok(_) => abort("expected error")
  }
}

///|
test "success: always ok" {
  assert_eq!(success(42).parse("anything"), Ok(("anything", 42)))
}

///|
test "fail: always error" {
  let result : Result[(String, Int), ParseError] = fail("oops").parse("input")
  assert_eq!(result.is_err(), true)
}
