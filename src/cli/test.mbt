///|
test "cli normalizes executable-prefixed args" {
  let args = normalized_cli_args(["parkit", "generate", "antlr", "./hello.g4"])
  assert_eq(args.length(), 3)
  assert_eq(args[0], "generate")
  assert_eq(args[1], "antlr")
  assert_eq(args[2], "./hello.g4")
}

///|
test "cli parses manifest fields" {
  let manifest = "{\n" +
    "  \"name\": \"demo/tool\",\n" +
    "  \"source\": \"src\"\n" +
    "}"
  assert_eq(module_name_from_manifest(manifest), Ok("demo/tool"))
  assert_eq(source_root_from_manifest(manifest), "src")
}

///|
test "cli derives package segment from grammar file" {
  assert_eq(grammar_segment("./Hello-World.g4"), Ok("hello_world"))
}

///|
test "cli parses out flag after grammar path" {
  let config = match
    parse_generate_antlr_args(["./hello.g4", "--out", "./src/generated/hello"]) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  assert_eq(config.grammar_path, "./hello.g4")
  assert_eq(config.out_path, Some("./src/generated/hello"))
}

///|
test "cli parses out flag before grammar path" {
  let config = match
    parse_generate_antlr_args(["--out=./src/generated/hello", "./hello.g4"]) {
    Ok(value) => value
    Err(error) => abort(error)
  }
  assert_eq(config.grammar_path, "./hello.g4")
  assert_eq(config.out_path, Some("./src/generated/hello"))
}

///|
test "cli derives package suffix from explicit output dir" {
  assert_eq(
    package_suffix_for_output_dir("src", "./src/generated/hello"),
    Ok("generated/hello"),
  )
}

///|
test "cli rejects output dir outside source root" {
  assert_eq(
    package_suffix_for_output_dir("src", "./examples/antlr/hello"),
    Err("`--out` must stay under `src`"),
  )
}
