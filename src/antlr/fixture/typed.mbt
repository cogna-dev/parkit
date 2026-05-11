///|
/// One typed CST fixture with grammar source and representative input.
pub struct TcstFixture {
  id : String
  source : String
  input : String
}

///|
priv struct TcstFixtureCatalogEntry {
  id : String
  grammar_path : String
  input_path : String
}

///|
fn tcst_fixture_catalog_path(resource_root : String) -> String {
  resource_root + "/tcst/catalog.tsv"
}

///|
fn tcst_fixture_resource_path(
  resource_root : String,
  relative_path : String,
) -> String {
  resource_root + "/" + relative_path
}

///|
fn parse_tcst_fixture_catalog_line(
  line : String,
  line_number : Int,
) -> TcstFixtureCatalogEntry? {
  let trimmed = line.trim()
  if trimmed == "" || trimmed.has_prefix("#") {
    return None
  }
  let fields = line.split("\t").map(field => field.to_string()).to_array()
  if fields.length() != 3 {
    abort(
      "invalid typed CST fixture catalog field count in line " +
      line_number.to_string(),
    )
  }
  Some({
    id: parse_string_field(fields[0]),
    grammar_path: parse_string_field(fields[1]),
    input_path: parse_string_field(fields[2]),
  })
}

///|
fn read_tcst_fixture_catalog_entries() -> Array[TcstFixtureCatalogEntry] {
  let resource_root = fixture_resource_root()
  let catalog_lines = read_text_file_or_abort(
      tcst_fixture_catalog_path(resource_root),
    )
    .split("\n")
    .map(line => line.to_string())
    .to_array()
  let entries : Array[TcstFixtureCatalogEntry] = []
  for index = 0; index < catalog_lines.length(); index = index + 1 {
    match parse_tcst_fixture_catalog_line(catalog_lines[index], index + 1) {
      Some(entry) => entries.push(entry)
      None => ()
    }
  }
  entries
}

///|
fn make_tcst_fixture(entry : TcstFixtureCatalogEntry) -> TcstFixture {
  let resource_root = fixture_resource_root()
  {
    id: entry.id,
    source: read_text_file_or_abort(
      tcst_fixture_resource_path(resource_root, entry.grammar_path),
    ),
    input: trim_terminal_newline(
      read_text_file_or_abort(
        tcst_fixture_resource_path(resource_root, entry.input_path),
      ),
    ),
  }
}

///|
/// Return representative typed CST fixtures used by generated-package and lowering tests.
///
/// Example:
/// let fixture = representative_tcst_fixtures()[0]
/// inspect(fixture.source.length() > 0, content="true")
///
/// Notes:
/// - The catalog keeps grammar and input file paths under repository-managed resources.
/// - The API intentionally exposes only the source and input required by typed CST tests.
pub fn representative_tcst_fixtures() -> Array[TcstFixture] {
  let fixtures : Array[TcstFixture] = []
  for entry in read_tcst_fixture_catalog_entries() {
    fixtures.push(make_tcst_fixture(entry))
  }
  fixtures
}
