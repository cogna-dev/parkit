///|
/// Vendored ANTLR upstream grammar fixture consumed by frontend compatibility tests.
///
/// Example:
/// let fixture = @antlr_fixture.supported_frontend_fixtures()[0]
/// inspect(fixture.source.length() > 0, content="true")
///
/// Notes:
/// - `source` is read from the matching `.g4` file under `data/fixture/upstream/` via `moonbitlang/x/fs`.
/// - The fixture metadata comes from the external `data/fixture/catalog.tsv` file.
/// - Update fixture text by editing the vendored `.g4` file, not by inlining new string literals in MoonBit code.
pub struct UpstreamGrammarFixture {
  id : String
  upstream_path : String
  grammar_name : String
  source : String
  expected_rule_count : Int
  left_recursive_rule_names : Array[String]
  current_gap : String?
}

///|
/// Return the vendored upstream grammars that must pass the current frontend pipeline.
///
/// Example:
/// let fixtures = @antlr_fixture.supported_frontend_fixtures()
/// inspect(fixtures.length() > 0, content="true")
///
/// Notes:
/// - The returned fixtures are loaded at runtime from `data/fixture/catalog.tsv` and `data/fixture/upstream/`.
/// - Add new upstream coverage by vendoring a `.g4` file first, then extending the external catalog file.
pub fn supported_frontend_fixtures() -> Array[UpstreamGrammarFixture] {
  supported_fixture_catalog()
}

///|
/// Return upstream grammars already chosen as the next compatibility drivers, but still blocked by known frontend gaps.
///
/// Example:
/// let pending = @antlr_fixture.pending_frontend_fixtures()
/// inspect(pending.length(), content="0")
///
/// Notes:
/// - Keep `current_gap` populated for every pending fixture so failure intent stays explicit.
/// - Promote a fixture here only after its `.g4` source has been vendored into `data/fixture/upstream/` and cataloged in `data/fixture/catalog.tsv`.
pub fn pending_frontend_fixtures() -> Array[UpstreamGrammarFixture] {
  pending_fixture_catalog()
}
