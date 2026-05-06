///|
priv struct FixtureCatalogEntry {
  bucket : String
  id : String
  upstream_path : String
  grammar_name : String
  expected_rule_count : Int
  left_recursive_rule_names : Array[String]
  current_gap : String?
}

///|
let fixture_resource_root_candidates : Array[String] = [
  "src/antlr/data/fixture", "../data/fixture",
]

///|
fn fixture_resource_root() -> String {
  for candidate in fixture_resource_root_candidates {
    if @fs.path_exists(candidate) {
      return candidate
    }
  }
  abort("missing fixture resources directory")
}

///|
fn read_text_file_or_abort(path : String) -> String {
  @fs.read_file_to_string(path) catch {
    _ => abort("failed to read fixture file `" + path + "`")
  }
}

///|
fn fixture_catalog_path(resource_root : String) -> String {
  resource_root + "/catalog.tsv"
}

///|
fn fixture_source_path(
  resource_root : String,
  upstream_path : String,
) -> String {
  resource_root + "/upstream/" + upstream_path
}

///|
fn parse_string_field(raw : String) -> String {
  raw.trim().to_string()
}

///|
fn parse_optional_field(raw : String) -> String? {
  let value = raw.trim().to_string()
  if value == "" {
    None
  } else {
    Some(value)
  }
}

///|
fn parse_list_field(raw : String) -> Array[String] {
  let value = raw.trim().to_string()
  if value == "" {
    []
  } else {
    value.split(",").map(item => item.trim().to_string()).to_array()
  }
}

///|
fn parse_expected_rule_count(raw : String, line_number : Int) -> Int {
  @string.parse_int(raw.trim()) catch {
    _ =>
      abort(
        "invalid expected_rule_count in fixture catalog line " +
        line_number.to_string(),
      )
  }
}

///|
fn parse_catalog_line(line : String, line_number : Int) -> FixtureCatalogEntry? {
  let trimmed = line.trim()
  if trimmed == "" || trimmed.has_prefix("#") {
    return None
  }
  let fields = line.split("\t").map(field => field.to_string()).to_array()
  if fields.length() != 7 {
    abort(
      "invalid fixture catalog field count in line " + line_number.to_string(),
    )
  }
  Some({
    bucket: parse_string_field(fields[0]),
    id: parse_string_field(fields[1]),
    upstream_path: parse_string_field(fields[2]),
    grammar_name: parse_string_field(fields[3]),
    expected_rule_count: parse_expected_rule_count(fields[4], line_number),
    left_recursive_rule_names: parse_list_field(fields[5]),
    current_gap: parse_optional_field(fields[6]),
  })
}

///|
fn read_fixture_catalog_entries() -> Array[FixtureCatalogEntry] {
  let resource_root = fixture_resource_root()
  let catalog_lines = read_text_file_or_abort(
      fixture_catalog_path(resource_root),
    )
    .split("\n")
    .map(line => line.to_string())
    .to_array()
  let entries : Array[FixtureCatalogEntry] = []
  for index = 0; index < catalog_lines.length(); index = index + 1 {
    match parse_catalog_line(catalog_lines[index], index + 1) {
      Some(entry) => entries.push(entry)
      None => ()
    }
  }
  entries
}

///|
fn make_fixture(entry : FixtureCatalogEntry) -> UpstreamGrammarFixture {
  let resource_root = fixture_resource_root()
  {
    id: entry.id,
    upstream_path: entry.upstream_path,
    grammar_name: entry.grammar_name,
    source: read_text_file_or_abort(
      fixture_source_path(resource_root, entry.upstream_path),
    ),
    expected_rule_count: entry.expected_rule_count,
    left_recursive_rule_names: entry.left_recursive_rule_names,
    current_gap: entry.current_gap,
  }
}

///|
fn supported_fixture_catalog() -> Array[UpstreamGrammarFixture] {
  let fixtures : Array[UpstreamGrammarFixture] = []
  for entry in read_fixture_catalog_entries() {
    if entry.bucket == "supported" {
      fixtures.push(make_fixture(entry))
    }
  }
  fixtures
}

///|
fn pending_fixture_catalog() -> Array[UpstreamGrammarFixture] {
  let fixtures : Array[UpstreamGrammarFixture] = []
  for entry in read_fixture_catalog_entries() {
    if entry.bucket == "pending" {
      fixtures.push(make_fixture(entry))
    }
  }
  fixtures
}
