// Tests for the JSON parser

///|
test "parse null" {
  assert_eq!(parse("null"), Ok(Null))
}

///|
test "parse true" {
  assert_eq!(parse("true"), Ok(Bool(true)))
}

///|
test "parse false" {
  assert_eq!(parse("false"), Ok(Bool(false)))
}

///|
test "parse integer number" {
  match parse("42") {
    Ok(Number(n)) => assert_eq!((n - 42.0).abs() < 1.0e-10, true)
    _ => abort("expected Number(42)")
  }
}

///|
test "parse negative number" {
  match parse("-3.14") {
    Ok(Number(n)) => assert_eq!((n + 3.14).abs() < 1.0e-10, true)
    _ => abort("expected Number(-3.14)")
  }
}

///|
test "parse simple string" {
  assert_eq!(parse("\"hello\""), Ok(Str("hello")))
}

///|
test "parse string with escape" {
  assert_eq!(parse("\"hello\\nworld\""), Ok(Str("hello\nworld")))
}

///|
test "parse string with unicode escape" {
  assert_eq!(parse("\"\\u0041\""), Ok(Str("A")))
}

///|
test "parse empty array" {
  assert_eq!(parse("[]"), Ok(Array([])))
}

///|
test "parse array of numbers" {
  match parse("[1, 2, 3]") {
    Ok(Array(arr)) => {
      assert_eq!(arr.length(), 3)
      match arr[0] {
        Number(n) => assert_eq!((n - 1.0).abs() < 1.0e-10, true)
        _ => abort("expected number")
      }
    }
    _ => abort("expected array")
  }
}

///|
test "parse empty object" {
  match parse("{}") {
    Ok(Object(pairs)) => assert_eq!(pairs.length(), 0)
    _ => abort("expected empty object")
  }
}

///|
test "parse simple object" {
  match parse("{\"key\": \"value\"}") {
    Ok(Object(pairs)) => {
      assert_eq!(pairs.length(), 1)
      assert_eq!(pairs[0].0, "key")
      assert_eq!(pairs[0].1, Str("value"))
    }
    _ => abort("expected object")
  }
}

///|
test "parse nested object" {
  let input =
    #|{"name": "Alice", "age": 30, "scores": [95, 87, 92]}
  match parse(input) {
    Ok(Object(pairs)) => {
      assert_eq!(pairs.length(), 3)
      assert_eq!(pairs[0].0, "name")
      assert_eq!(pairs[0].1, Str("Alice"))
    }
    _ => abort("expected object")
  }
}

///|
test "parse whitespace around values" {
  assert_eq!(parse("  null  "), Ok(Null))
  assert_eq!(parse("  true  "), Ok(Bool(true)))
}

///|
test "parse trailing input fails" {
  assert_eq!(parse("null extra").is_err(), true)
}

///|
test "parse empty input fails" {
  assert_eq!(parse("").is_err(), true)
}

///|
test "parse complex nested structure" {
  let input =
    #|{
    #|  "name": "JSON Test",
    #|  "version": 1,
    #|  "features": ["parsing", "combinators"],
    #|  "nested": {
    #|    "a": true,
    #|    "b": null,
    #|    "c": -1.5e2
    #|  }
    #|}
  match parse(input) {
    Ok(Object(pairs)) => assert_eq!(pairs.length(), 4)
    _ => abort("expected object with 4 pairs")
  }
}
