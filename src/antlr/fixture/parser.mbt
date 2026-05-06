///|
/// One parser runtime golden fixture with grammar, input, hooks, and expected serialized run.
pub struct ParserGoldenSnapshotFixture {
  id : String
  source : String
  input : String
  expected_serialized_run : String
  lexer_true_predicates : Array[String]
  lexer_action_labels : Array[LexerSnapshotActionLabel]
  parser_true_predicates : Array[String]
  parser_action_labels : Array[LexerSnapshotActionLabel]
}

///|
priv struct ParserSnapshotCatalogEntry {
  bucket : String
  id : String
  grammar_path : String
  input_path : String
  snapshot_path : String
  lexer_true_predicates : Array[String]
  lexer_action_labels : Array[LexerSnapshotActionLabel]
  parser_true_predicates : Array[String]
  parser_action_labels : Array[LexerSnapshotActionLabel]
}

///|
fn parser_snapshot_catalog_path(resource_root : String) -> String {
  resource_root + "/parser/catalog.tsv"
}

///|
fn parser_snapshot_resource_path(
  resource_root : String,
  relative_path : String,
) -> String {
  resource_root + "/" + relative_path
}

///|
fn parse_parser_snapshot_catalog_line(
  line : String,
  line_number : Int,
) -> ParserSnapshotCatalogEntry? {
  let trimmed = line.trim()
  if trimmed == "" || trimmed.has_prefix("#") {
    return None
  }
  let fields = line.split("\t").map(field => field.to_string()).to_array()
  if fields.length() != 9 {
    abort(
      "invalid parser snapshot catalog field count in line " +
      line_number.to_string(),
    )
  }
  Some({
    bucket: parse_string_field(fields[0]),
    id: parse_string_field(fields[1]),
    grammar_path: parse_string_field(fields[2]),
    input_path: parse_string_field(fields[3]),
    snapshot_path: parse_string_field(fields[4]),
    lexer_true_predicates: parse_list_field(fields[5]),
    lexer_action_labels: parse_action_label_field(fields[6], line_number),
    parser_true_predicates: parse_list_field(fields[7]),
    parser_action_labels: parse_action_label_field(fields[8], line_number),
  })
}

///|
fn read_parser_snapshot_catalog_entries() -> Array[ParserSnapshotCatalogEntry] {
  let resource_root = fixture_resource_root()
  let catalog_lines = read_text_file_or_abort(
      parser_snapshot_catalog_path(resource_root),
    )
    .split("\n")
    .map(line => line.to_string())
    .to_array()
  let entries : Array[ParserSnapshotCatalogEntry] = []
  for index = 0; index < catalog_lines.length(); index = index + 1 {
    match parse_parser_snapshot_catalog_line(catalog_lines[index], index + 1) {
      Some(entry) => entries.push(entry)
      None => ()
    }
  }
  entries
}

///|
fn make_parser_snapshot_fixture(
  entry : ParserSnapshotCatalogEntry,
) -> ParserGoldenSnapshotFixture {
  let resource_root = fixture_resource_root()
  {
    id: entry.id,
    source: read_text_file_or_abort(
      parser_snapshot_resource_path(resource_root, entry.grammar_path),
    ),
    input: trim_terminal_newline(
      read_text_file_or_abort(
        parser_snapshot_resource_path(resource_root, entry.input_path),
      ),
    ),
    expected_serialized_run: trim_terminal_newline(
      read_text_file_or_abort(
        parser_snapshot_resource_path(resource_root, entry.snapshot_path),
      ),
    ),
    lexer_true_predicates: entry.lexer_true_predicates,
    lexer_action_labels: entry.lexer_action_labels,
    parser_true_predicates: entry.parser_true_predicates,
    parser_action_labels: entry.parser_action_labels,
  }
}

///|
/// Return representative local parser-runtime fixtures and their golden snapshots.
///
/// Example:
/// let fixture = representative_parser_snapshots()[0]
/// inspect(fixture.expected_serialized_run.length() > 0, content="true")
///
/// Notes:
/// - Grammar sources stay as standalone `.g4` files under repository-managed resource directories.
/// - Snapshot inputs are normalized to ignore one trailing terminal newline.
pub fn representative_parser_snapshots() -> Array[ParserGoldenSnapshotFixture] {
  let fixtures : Array[ParserGoldenSnapshotFixture] = []
  for entry in read_parser_snapshot_catalog_entries() {
    if entry.bucket == "representative" {
      fixtures.push(make_parser_snapshot_fixture(entry))
    }
  }
  fixtures
}

///|
/// Return upstream parser-runtime fixtures and their golden snapshots.
///
/// Example:
/// let fixtures = upstream_parser_snapshots()
/// inspect(fixtures.length() > 0, content="true")
///
/// Notes:
/// - These fixtures reuse vendored upstream `.g4` sources under `resources/upstream`.
/// - Keep the snapshot expectations stable so parser-runtime changes show up as explicit diffs.
pub fn upstream_parser_snapshots() -> Array[ParserGoldenSnapshotFixture] {
  let fixtures : Array[ParserGoldenSnapshotFixture] = []
  for entry in read_parser_snapshot_catalog_entries() {
    if entry.bucket == "upstream" {
      fixtures.push(make_parser_snapshot_fixture(entry))
    }
  }
  fixtures
}
