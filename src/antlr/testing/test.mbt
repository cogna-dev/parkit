///|
let spec_root_candidates : Array[String] = ["src/antlr/spec", "../spec"]

///|
fn spec_root() -> String {
  for candidate in spec_root_candidates {
    if @fs.path_exists(candidate) {
      return candidate
    }
  }
  abort("missing antlr spec directory")
}

///|
fn read_spec_text_or_abort(file_name : String) -> String {
  @fs.read_file_to_string(spec_root() + "/" + file_name) catch {
    _ => abort("failed to read spec file `" + file_name + "`")
  }
}

///|
fn assert_document_matches(
  actual : String,
  expected : String,
  label : String,
) -> Unit {
  if actual != expected {
    println(actual)
    abort(label + " drifted from generated compatibility output")
  }
}

///|
fn descriptor_ids() -> Array[String] {
  let ids : Array[String] = []
  for descriptor in compatibility_catalog() {
    ids.push(descriptor.suite_id)
  }
  ids
}

///|
fn ids_are_unique(values : Array[String]) -> Bool {
  for index = 0; index < values.length(); index = index + 1 {
    for other = index + 1; other < values.length(); other = other + 1 {
      if values[index] == values[other] {
        return false
      }
    }
  }
  true
}

///|
test "compatibility catalog keeps suite ids unique" {
  let ids = descriptor_ids()
  assert_eq(ids.length(), 25)
  assert_eq(ids_are_unique(ids), true)
}

///|
test "compatibility summary matches current catalog counts" {
  let summary = compatibility_summary()
  assert_eq(summary.total_suites, 25)
  assert_eq(summary.passing_suites, 24)
  assert_eq(summary.porting_suites, 0)
  assert_eq(summary.planned_suites, 0)
  assert_eq(summary.blocked_suites, 1)
}

///|
test "support matrix renders contract and upstream sections" {
  let report = render_support_matrix()
  assert_eq(report.has_prefix("# ANTLR Support Matrix"), true)
  assert_eq(report.contains("## Repo-Local Contract Suites"), true)
  assert_eq(report.contains("## Upstream Mirror Suites"), true)
  assert_eq(
    report.contains(
      "| listeners | upstream-mirror | compatibility | compatibility | runtime-testsuite/Listeners | Listeners Mirror | blocked |",
    ),
    true,
  )
}

///|
test "compatibility statement stays behavior scoped" {
  let statement = render_compatibility_statement()
  assert_eq(statement.has_prefix("# ANTLR Compatibility Statement"), true)
  assert_eq(statement.contains("versioned CstDocument"), true)
  assert_eq(
    statement.contains("generated recognizer/listener/visitor parity"),
    true,
  )
  assert_eq(statement.contains("当前 suite 快照"), true)
}

///|
test "suite groups stay aligned with ci-facing taxonomy" {
  let groups = suite_groups()
  assert_eq(groups.length(), 4)
  assert_eq(groups[0], "frontend-atn")
  assert_eq(groups[1], "runtime")
  assert_eq(groups[2], "cst")
  assert_eq(groups[3], "compatibility")
}

///|
test "support matrix document matches generated report" {
  assert_document_matches(
    render_support_matrix(),
    read_spec_text_or_abort("support-matrix.md"),
    "support matrix",
  )
}

///|
test "compatibility statement document matches generated report" {
  assert_document_matches(
    render_compatibility_statement(),
    read_spec_text_or_abort("compatibility-statement.md"),
    "compatibility statement",
  )
}
