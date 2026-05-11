///|
/// One host action label binding used by a lexer golden fixture.
pub struct LexerSnapshotActionLabel {
  text : String
  label : String
}

///|
/// One lexer runtime golden fixture with source, input, and expected serialized run.
pub struct LexerGoldenSnapshotFixture {
  id : String
  source : String
  input : String
  expected_serialized_run : String
  true_predicates : Array[String]
  action_labels : Array[LexerSnapshotActionLabel]
}

///|
/// Return representative local lexer-runtime fixtures and their golden snapshots.
///
/// Example:
/// let fixture = representative_lexer_snapshots()[0]
/// inspect(fixture.expected_serialized_run.length() > 0, content="true")
///
/// Notes:
/// - Grammar sources stay as standalone `.g4` files under `resources/lexer/grammars/`.
/// - Input and snapshot files are normalized to ignore one trailing terminal newline.
/// - Predicate and action host bindings are declared in the catalog, not in test code.
pub fn representative_lexer_snapshots() -> Array[LexerGoldenSnapshotFixture] {
  let fixtures : Array[LexerGoldenSnapshotFixture] = []
  for entry in read_lexer_snapshot_catalog_entries() {
    if entry.bucket == "representative" {
      fixtures.push(make_lexer_snapshot_fixture(entry))
    }
  }
  fixtures
}

///|
/// Return upstream lexer-runtime fixtures and their golden snapshots.
///
/// Example:
/// let fixtures = upstream_lexer_snapshots()
/// inspect(fixtures.length() > 0, content="true")
///
/// Notes:
/// - These fixtures reuse upstream `.g4` sources mirrored under `resources/upstream/`.
/// - Keep the snapshot expectations stable so runtime changes show up as explicit diffs.
pub fn upstream_lexer_snapshots() -> Array[LexerGoldenSnapshotFixture] {
  let fixtures : Array[LexerGoldenSnapshotFixture] = []
  for entry in read_lexer_snapshot_catalog_entries() {
    if entry.bucket == "upstream" {
      fixtures.push(make_lexer_snapshot_fixture(entry))
    }
  }
  fixtures
}

///|
priv struct LexerSnapshotCatalogEntry {
  bucket : String
  id : String
  grammar_path : String
  input_path : String
  snapshot_path : String
  true_predicates : Array[String]
  action_labels : Array[LexerSnapshotActionLabel]
}

///|
fn lexer_snapshot_catalog_path(resource_root : String) -> String {
  resource_root + "/lexer/catalog.tsv"
}

///|
fn lexer_snapshot_resource_path(
  resource_root : String,
  relative_path : String,
) -> String {
  resource_root + "/" + relative_path
}

///|
fn parse_action_label_entry(
  raw : String,
  line_number : Int,
) -> LexerSnapshotActionLabel {
  let parts = raw.split("=").map(part => part.trim().to_string()).to_array()
  if parts.length() != 2 {
    abort(
      "invalid lexer snapshot action label in line " + line_number.to_string(),
    )
  }
  { text: parse_string_field(parts[0]), label: parse_string_field(parts[1]) }
}

///|
fn parse_action_label_field(
  raw : String,
  line_number : Int,
) -> Array[LexerSnapshotActionLabel] {
  let value = raw.trim().to_string()
  if value == "" {
    return []
  }
  let labels : Array[LexerSnapshotActionLabel] = []
  for item in value.split(",").map(part => part.trim().to_string()).to_array() {
    labels.push(parse_action_label_entry(item, line_number))
  }
  labels
}

///|
fn parse_lexer_snapshot_catalog_line(
  line : String,
  line_number : Int,
) -> LexerSnapshotCatalogEntry? {
  let trimmed = line.trim()
  if trimmed == "" || trimmed.has_prefix("#") {
    return None
  }
  let fields = line.split("\t").map(field => field.to_string()).to_array()
  if fields.length() != 7 {
    abort(
      "invalid lexer snapshot catalog field count in line " +
      line_number.to_string(),
    )
  }
  Some({
    bucket: parse_string_field(fields[0]),
    id: parse_string_field(fields[1]),
    grammar_path: parse_string_field(fields[2]),
    input_path: parse_string_field(fields[3]),
    snapshot_path: parse_string_field(fields[4]),
    true_predicates: parse_list_field(fields[5]),
    action_labels: parse_action_label_field(fields[6], line_number),
  })
}

///|
fn read_lexer_snapshot_catalog_entries() -> Array[LexerSnapshotCatalogEntry] {
  let resource_root = fixture_resource_root()
  let catalog_lines = read_text_file_or_abort(
      lexer_snapshot_catalog_path(resource_root),
    )
    .split("\n")
    .map(line => line.to_string())
    .to_array()
  let entries : Array[LexerSnapshotCatalogEntry] = []
  for index = 0; index < catalog_lines.length(); index = index + 1 {
    match parse_lexer_snapshot_catalog_line(catalog_lines[index], index + 1) {
      Some(entry) => entries.push(entry)
      None => ()
    }
  }
  entries
}

///|
fn make_lexer_snapshot_fixture(
  entry : LexerSnapshotCatalogEntry,
) -> LexerGoldenSnapshotFixture {
  let resource_root = fixture_resource_root()
  {
    id: entry.id,
    source: read_text_file_or_abort(
      lexer_snapshot_resource_path(resource_root, entry.grammar_path),
    ),
    input: trim_terminal_newline(
      read_text_file_or_abort(
        lexer_snapshot_resource_path(resource_root, entry.input_path),
      ),
    ),
    expected_serialized_run: trim_terminal_newline(
      read_text_file_or_abort(
        lexer_snapshot_resource_path(resource_root, entry.snapshot_path),
      ),
    ),
    true_predicates: entry.true_predicates,
    action_labels: entry.action_labels,
  }
}
