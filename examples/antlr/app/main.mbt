///|
fn greeting_name(input : String) -> Result[String, String] {
  let root = match @hello.parse(input) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match root.last_token() {
    Some(token) => Ok(token.lexeme)
    None => Err("expected a trailing token in parsed greeting")
  }
}

///|
test "antlr example parses greeting" {
  assert_eq(greeting_name("hello moonbit"), Ok("moonbit"))
}

///|
fn main {
  match greeting_name("hello moonbit") {
    Ok(name) => println("hello " + name)
    Err(error) => abort(error)
  }
}
