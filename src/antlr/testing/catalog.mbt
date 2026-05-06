///|
let suite_resource_root_candidates : Array[String] = [
  "src/antlr/data/testing/suites", "../data/testing/suites",
]

///|
fn suite_resource_root() -> String {
  for candidate in suite_resource_root_candidates {
    if @fs.path_exists(candidate) {
      return candidate
    }
  }
  abort("missing compatibility suite resources directory")
}

///|
fn read_text_file_or_abort(path : String) -> String {
  @fs.read_file_to_string(path) catch {
    _ => abort("failed to read compatibility file `" + path + "`")
  }
}

///|
fn suite_catalog_file_path(resource_root : String) -> String {
  resource_root + "/catalog.tsv"
}

///|
fn parse_string_field(raw : String) -> String {
  raw.trim().to_string()
}

///|
fn parse_optional_field(raw : String) -> String? {
  let value = raw.trim().to_string()
  if value == "" || value == "-" {
    None
  } else {
    Some(value)
  }
}

///|
fn parse_list_field(raw : String) -> Array[String] {
  let value = raw.trim().to_string()
  if value == "" || value == "-" {
    []
  } else {
    value.split(";").map(item => item.trim().to_string()).to_array()
  }
}

///|
fn parse_suite_kind(raw : String, line_number : Int) -> CompatibilitySuiteKind {
  let value = raw.trim().to_string()
  if value == "contract" {
    ContractSuite
  } else if value == "upstream-mirror" {
    UpstreamMirrorSuite
  } else {
    abort(
      "invalid compatibility suite kind in catalog line " +
      line_number.to_string(),
    )
  }
}

///|
fn parse_layer(raw : String, line_number : Int) -> CompatibilityLayer {
  let value = raw.trim().to_string()
  if value == "frontend" {
    FrontendContract
  } else if value == "atn" {
    AtnContract
  } else if value == "runtime" {
    RuntimeContract
  } else if value == "cst" {
    CstContract
  } else if value == "compatibility" {
    CompatibilityGovernance
  } else {
    abort(
      "invalid compatibility layer in catalog line " + line_number.to_string(),
    )
  }
}

///|
fn parse_status(raw : String, line_number : Int) -> CompatibilityStatus {
  let value = raw.trim().to_string()
  if value == "planned" {
    Planned
  } else if value == "porting" {
    Porting
  } else if value == "passing" {
    Passing
  } else if value == "blocked" {
    Blocked
  } else {
    abort(
      "invalid compatibility status in catalog line " + line_number.to_string(),
    )
  }
}

///|
fn parse_catalog_line(
  line : String,
  line_number : Int,
) -> CompatibilityDescriptor? {
  let trimmed = line.trim()
  if trimmed == "" || trimmed.has_prefix("#") {
    return None
  }
  if line_number == 1 && trimmed.has_prefix("id\tname\tkind") {
    return None
  }
  let fields = line.split("\t").map(field => field.to_string()).to_array()
  if fields.length() != 12 {
    abort(
      "invalid compatibility catalog field count in line " +
      line_number.to_string(),
    )
  }
  Some({
    suite_id: parse_string_field(fields[0]),
    suite_name: parse_string_field(fields[1]),
    suite_kind: parse_suite_kind(fields[2], line_number),
    suite_group: parse_string_field(fields[3]),
    layer: parse_layer(fields[4], line_number),
    status: parse_status(fields[5], line_number),
    upstream_reference: parse_optional_field(fields[6]),
    evidence_command: parse_string_field(fields[7]),
    test_files: parse_list_field(fields[8]),
    resource_catalogs: parse_list_field(fields[9]),
    known_gap: parse_optional_field(fields[10]),
    blocked_reason: parse_optional_field(fields[11]),
  })
}

///|
fn read_compatibility_catalog() -> Array[CompatibilityDescriptor] {
  let lines = read_text_file_or_abort(
      suite_catalog_file_path(suite_resource_root()),
    )
    .split("\n")
    .map(line => line.to_string())
    .to_array()
  let entries : Array[CompatibilityDescriptor] = []
  for index = 0; index < lines.length(); index = index + 1 {
    match parse_catalog_line(lines[index], index + 1) {
      Some(entry) => entries.push(entry)
      None => ()
    }
  }
  entries
}

///|
/// Return the current machine-readable compatibility catalog for the ANTLR mainline.
///
/// Example:
/// let catalog = compatibility_catalog()
/// inspect(catalog.length() > 0, content="true")
///
/// Notes:
/// - Rows are read from `src/antlr/data/testing/suites/catalog.tsv`, which is the single source of truth for Phase 5 suite metadata.
/// - Order is preserved from the TSV so markdown reports and CI group summaries stay stable across runs.
pub fn compatibility_catalog() -> Array[CompatibilityDescriptor] {
  read_compatibility_catalog()
}

///|
/// Find one compatibility descriptor by exact suite id.
///
/// Example:
/// let descriptor = find_compatibility_descriptor("cst-contract")
/// inspect(descriptor is Some(_), content="true")
///
/// Notes:
/// - Matching is exact and case-sensitive.
/// - Returns `None` when the catalog does not define the requested suite id.
pub fn find_compatibility_descriptor(
  suite_id : String,
) -> CompatibilityDescriptor? {
  for descriptor in compatibility_catalog() {
    if descriptor.suite_id == suite_id {
      return Some(descriptor)
    }
  }
  None
}
