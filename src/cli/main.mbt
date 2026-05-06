///|
fn usage() -> String {
  "usage: parkit generate antlr [--out ./src/hello] ./hello.g4"
}

///|
struct GenerateAntlrArgs {
  grammar_path : String
  out_path : String?
}

///|
fn workspace_root() -> Result[String, String] {
  match @env.current_dir() {
    Some(path) => Ok(path)
    None => Err("cannot determine current working directory")
  }
}

///|
fn join_segments(parts : Array[String]) -> String {
  if parts.length() == 0 {
    return ""
  }
  let mut path = parts[0]
  for index = 1; index < parts.length(); index = index + 1 {
    path = path + "/" + parts[index]
  }
  path
}

///|
fn normalized_path(raw : String) -> String {
  let trimmed = raw.trim().to_string()
  let absolute = trimmed.has_prefix("/")
  let parts : Array[String] = []
  for piece in trimmed.split("/").map(part => part.to_string()).to_array() {
    let part = piece.trim().to_string()
    if part == "" || part == "." {
      ()
    } else {
      parts.push(part)
    }
  }
  if parts.length() == 0 {
    if absolute {
      "/"
    } else {
      "."
    }
  } else {
    let joined = join_segments(parts)
    if absolute {
      "/" + joined
    } else {
      joined
    }
  }
}

///|
fn join_path(base : String, child : String) -> String {
  let clean_base = normalized_path(base)
  let clean_child = normalized_path(child)
  if clean_base == "" || clean_base == "." {
    clean_child
  } else if clean_child == "" || clean_child == "." {
    clean_base
  } else if clean_base.has_suffix("/") {
    clean_base + clean_child
  } else {
    clean_base + "/" + clean_child
  }
}

///|
fn resolve_workspace_path(workspace : String, path : String) -> String {
  let clean_path = normalized_path(path)
  if clean_path.has_prefix("/") {
    clean_path
  } else {
    join_path(workspace, clean_path)
  }
}

///|
fn read_text(path : String) -> Result[String, String] {
  let text = @fs.read_file_to_string(path) catch {
    _ => return Err("failed to read `" + path + "`")
  }
  Ok(text)
}

///|
fn manifest_string_field(text : String, key : String) -> String? {
  let prefix = "\"" + key + "\""
  for raw_line in text.split("\n").map(line => line.to_string()).to_array() {
    let line = raw_line.trim().to_string()
    if !line.has_prefix(prefix) {
      continue
    }
    let parts = line.split(":").map(part => part.to_string()).to_array()
    if parts.length() < 2 {
      return None
    }
    let raw_value = parts[1].trim().to_string()
    let value = if raw_value.has_suffix(",") {
      raw_value[0:raw_value.length() - 1].to_string()
    } else {
      raw_value
    }
    if value.length() >= 2 && value.has_prefix("\"") && value.has_suffix("\"") {
      return Some(value[1:value.length() - 1].to_string())
    }
    return None
  }
  None
}

///|
fn module_name_from_manifest(text : String) -> Result[String, String] {
  match manifest_string_field(text, "name") {
    Some(value) => Ok(value)
    None => Err("missing `name` in moon.mod.json")
  }
}

///|
fn source_root_from_manifest(text : String) -> String {
  match manifest_string_field(text, "source") {
    Some(value) if value != "" => value
    _ => "src"
  }
}

///|
fn cli_ascii_lower(c : Char) -> Char {
  if c >= 'A' && c <= 'Z' {
    (c.to_int() - 'A'.to_int() + 'a'.to_int()).unsafe_to_char()
  } else {
    c
  }
}

///|
fn cli_is_alphanumeric(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
}

///|
fn package_segment(raw : String) -> String {
  let mut result = ""
  let mut pending_separator = false
  for c in raw {
    if cli_is_alphanumeric(c) {
      if pending_separator && result != "" {
        result = result + "_"
      }
      result = result + String::make(1, cli_ascii_lower(c))
      pending_separator = false
    } else if result != "" {
      pending_separator = true
    }
  }
  result
}

///|
fn grammar_segment(path : String) -> Result[String, String] {
  let parts = normalized_path(path)
    .split("/")
    .map(part => part.to_string())
    .to_array()
  if parts.length() == 0 {
    return Err("grammar path must end with `.g4`")
  }
  let file_name = parts[parts.length() - 1].trim().to_string()
  if !file_name.has_suffix(".g4") || file_name.length() <= 3 {
    return Err("grammar path must end with `.g4`")
  }
  let stem = file_name[0:file_name.length() - 3].to_string()
  let segment = package_segment(stem)
  if segment == "" {
    return Err("grammar file name must contain letters or digits")
  }
  Ok(segment)
}

///|
fn workspace_relative_path(
  workspace : String,
  path : String,
) -> Result[String, String] {
  let clean_workspace = normalized_path(workspace)
  let clean_path = normalized_path(path)
  if clean_path == clean_workspace {
    return Ok(".")
  }
  let prefix = clean_workspace + "/"
  if clean_path.has_prefix(prefix) {
    return Ok(clean_path[prefix.length():clean_path.length()].to_string())
  }
  Err("`--out` must stay inside the current MoonBit project")
}

///|
fn package_suffix_for_output_dir(
  source_root : String,
  relative_output_dir : String,
) -> Result[String, String] {
  let clean_source_root = normalized_path(source_root)
  let clean_output_dir = normalized_path(relative_output_dir)
  if clean_output_dir == "." {
    return Err("output dir must include at least one package segment")
  }
  if clean_source_root == "." {
    return Ok(clean_output_dir)
  }
  if clean_output_dir == clean_source_root {
    return Err(
      "`--out` must point to a package directory under `" +
      clean_source_root +
      "`",
    )
  }
  let prefix = clean_source_root + "/"
  if !clean_output_dir.has_prefix(prefix) {
    return Err("`--out` must stay under `" + clean_source_root + "`")
  }
  Ok(clean_output_dir[prefix.length():clean_output_dir.length()].to_string())
}

///|
fn parse_generate_antlr_args(
  args : Array[String],
) -> Result[GenerateAntlrArgs, String] {
  let mut grammar_path : String? = None
  let mut out_path : String? = None
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    if arg == "--out" {
      if index + 1 >= args.length() {
        return Err("expected a path after `--out`")
      }
      if out_path is Some(_) {
        return Err("`--out` may only be provided once")
      }
      out_path = Some(args[index + 1])
      index = index + 2
      continue
    }
    if arg.has_prefix("--out=") {
      if out_path is Some(_) {
        return Err("`--out` may only be provided once")
      }
      let value = arg[6:arg.length()].to_string()
      if value == "" {
        return Err("expected a path after `--out`")
      }
      out_path = Some(value)
      index = index + 1
      continue
    }
    if arg.has_prefix("--") {
      return Err("unknown option `" + arg + "`")
    }
    if grammar_path is Some(_) {
      return Err(usage())
    }
    grammar_path = Some(arg)
    index = index + 1
  }
  match grammar_path {
    Some(path) => Ok({ grammar_path: path, out_path })
    None => Err(usage())
  }
}

///|
fn ensure_dir(path : String) -> Result[Unit, String] {
  let trimmed = path.trim().to_string()
  if trimmed == "" || trimmed == "." || @fs.path_exists(trimmed) {
    return Ok(())
  }
  let parts = trimmed.split("/").map(part => part.to_string()).to_array()
  let mut current = if trimmed.has_prefix("/") { "/" } else { "" }
  for part in parts {
    if part == "" || part == "." {
      continue
    }
    let next = if current == "" {
      part
    } else if current == "/" {
      "/" + part
    } else {
      current + "/" + part
    }
    if !@fs.path_exists(next) {
      @fs.create_dir(next) catch {
        _ => return Err("failed to create directory `" + next + "`")
      }
    }
    current = next
  }
  Ok(())
}

///|
fn write_generated_files(
  output_dir : String,
  files : Array[@antlr_tcst.TypedPackageFile],
) -> Result[Unit, String] {
  match ensure_dir(output_dir) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  for file in files {
    let path = join_path(output_dir, file.relative_path)
    @fs.write_string_to_file(path, file.content) catch {
      _ => return Err("failed to write `" + path + "`")
    }
  }
  Ok(())
}

///|
fn run_generate_antlr(config : GenerateAntlrArgs) -> Result[String, String] {
  let workspace = match workspace_root() {
    Ok(path) => path
    Err(error) => return Err(error)
  }
  let manifest_path = join_path(workspace, "moon.mod.json")
  let manifest_text = match read_text(manifest_path) {
    Ok(text) => text
    Err(error) => return Err(error)
  }
  let module_name = match module_name_from_manifest(manifest_text) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let source_root = source_root_from_manifest(manifest_text)
  let grammar_path = resolve_workspace_path(workspace, config.grammar_path)
  let grammar_source = match read_text(grammar_path) {
    Ok(text) => text
    Err(error) => return Err(error)
  }
  let default_output_dir = match grammar_segment(config.grammar_path) {
    Ok(value) => join_path(source_root, value)
    Err(error) => return Err(error)
  }
  let relative_output_dir = match config.out_path {
    Some(raw_path) => {
      let output_dir = resolve_workspace_path(workspace, raw_path)
      match workspace_relative_path(workspace, output_dir) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    }
    None => default_output_dir
  }
  let package_suffix = match
    package_suffix_for_output_dir(source_root, relative_output_dir) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let output_dir = resolve_workspace_path(workspace, relative_output_dir)
  let package_name = module_name + "/" + package_suffix
  let files = match
    @antlr_tcst.generate_typed_package(grammar_source, package_name) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match write_generated_files(output_dir, files) {
    Ok(_) => Ok("generated " + package_name + " at " + relative_output_dir)
    Err(error) => Err(error)
  }
}

///|
fn trailing_args(raw : Array[String], start : Int) -> Array[String] {
  let args : Array[String] = []
  for index = start; index < raw.length(); index = index + 1 {
    args.push(raw[index])
  }
  args
}

///|
fn normalized_cli_args(raw : Array[String]) -> Array[String] {
  if raw.length() >= 3 && raw[0] == "generate" {
    return raw
  }
  if raw.length() >= 4 && raw[1] == "generate" {
    let normalized : Array[String] = []
    for index = 1; index < raw.length(); index = index + 1 {
      normalized.push(raw[index])
    }
    return normalized
  }
  raw
}

///|
fn run_cli(args : Array[String]) -> Result[String, String] {
  if args.length() < 3 || args[0] != "generate" || args[1] != "antlr" {
    return Err(usage())
  }
  let config = match parse_generate_antlr_args(trailing_args(args, 2)) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  run_generate_antlr(config)
}

///|
fn main {
  let args = normalized_cli_args(@env.args())
  match run_cli(args) {
    Ok(message) => println(message)
    Err(error) => abort(error)
  }
}
