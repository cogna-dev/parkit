///|
pub struct AtnGoldenSnapshotFixture {
  id : String
  source : String
  expected_serialized_atn : String
}

///|
/// Return representative grammars together with their serialized ATN golden snapshots.
///
/// Example:
/// let fixture = @antlr_fixture.representative_atn_snapshots()[0]
/// inspect(fixture.expected_serialized_atn.length() > 0, content="true")
///
/// Notes:
/// - Grammar sources are read from `resources/atn/grammars/` via `moonbitlang/x/fs`.
/// - Golden files are read from `resources/atn/snapshots/` and normalized to ignore one trailing terminal newline.
/// - Update a representative grammar by editing its `.g4` file, then refresh the matching golden snapshot file.
pub fn representative_atn_snapshots() -> Array[AtnGoldenSnapshotFixture] {
  representative_atn_snapshot_catalog()
}

///|
priv struct AtnSnapshotCatalogEntry {
  id : String
  grammar_path : String
  snapshot_path : String
}

///|
fn atn_resource_root(resource_root : String) -> String {
  resource_root + "/atn"
}

///|
fn atn_snapshot_catalog_path(resource_root : String) -> String {
  atn_resource_root(resource_root) + "/catalog.tsv"
}

///|
fn atn_snapshot_resource_path(
  resource_root : String,
  relative_path : String,
) -> String {
  atn_resource_root(resource_root) + "/" + relative_path
}

///|
fn trim_terminal_newline(text : String) -> String {
  if text.has_suffix("\r\n") {
    text[:text.length() - 2].to_string()
  } else if text.has_suffix("\n") {
    text[:text.length() - 1].to_string()
  } else {
    text
  }
}

///|
fn parse_atn_snapshot_catalog_line(
  line : String,
  line_number : Int,
) -> AtnSnapshotCatalogEntry? {
  let trimmed = line.trim()
  if trimmed == "" || trimmed.has_prefix("#") {
    return None
  }
  let fields = line.split("\t").map(field => field.to_string()).to_array()
  if fields.length() != 3 {
    abort(
      "invalid ATN snapshot catalog field count in line " +
      line_number.to_string(),
    )
  }
  Some({
    id: parse_string_field(fields[0]),
    grammar_path: parse_string_field(fields[1]),
    snapshot_path: parse_string_field(fields[2]),
  })
}

///|
fn read_atn_snapshot_catalog_entries() -> Array[AtnSnapshotCatalogEntry] {
  let resource_root = fixture_resource_root()
  let catalog_lines = read_text_file_or_abort(
      atn_snapshot_catalog_path(resource_root),
    )
    .split("\n")
    .map(line => line.to_string())
    .to_array()
  let entries : Array[AtnSnapshotCatalogEntry] = []
  for index = 0; index < catalog_lines.length(); index = index + 1 {
    match parse_atn_snapshot_catalog_line(catalog_lines[index], index + 1) {
      Some(entry) => entries.push(entry)
      None => ()
    }
  }
  entries
}

///|
fn make_atn_snapshot_fixture(
  entry : AtnSnapshotCatalogEntry,
) -> AtnGoldenSnapshotFixture {
  let resource_root = fixture_resource_root()
  {
    id: entry.id,
    source: read_text_file_or_abort(
      atn_snapshot_resource_path(resource_root, entry.grammar_path),
    ),
    expected_serialized_atn: trim_terminal_newline(
      read_text_file_or_abort(
        atn_snapshot_resource_path(resource_root, entry.snapshot_path),
      ),
    ),
  }
}

///|
fn representative_atn_snapshot_catalog() -> Array[AtnGoldenSnapshotFixture] {
  let fixtures : Array[AtnGoldenSnapshotFixture] = []
  for entry in read_atn_snapshot_catalog_entries() {
    fixtures.push(make_atn_snapshot_fixture(entry))
  }
  fixtures
}
