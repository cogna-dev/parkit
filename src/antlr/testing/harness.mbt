///|
fn append_unique(values : Array[String], wanted : String) -> Unit {
  for value in values {
    if value == wanted {
      return
    }
  }
  values.push(wanted)
}

///|
/// Summarize the current compatibility catalog by status counts.
///
/// Example:
/// let summary = compatibility_summary()
/// inspect(summary.total_suites > 0, content="true")
///
/// Notes:
/// - The summary is derived directly from `compatibility_catalog()` and is intended for deterministic reports and CI assertions.
/// - Status counts always add up to `total_suites`.
pub fn compatibility_summary() -> CompatibilitySummary {
  let mut planned_suites = 0
  let mut porting_suites = 0
  let mut passing_suites = 0
  let mut blocked_suites = 0
  let catalog = compatibility_catalog()
  for descriptor in catalog {
    match descriptor.status {
      Planned => planned_suites = planned_suites + 1
      Porting => porting_suites = porting_suites + 1
      Passing => passing_suites = passing_suites + 1
      Blocked => blocked_suites = blocked_suites + 1
    }
  }
  {
    total_suites: catalog.length(),
    planned_suites,
    porting_suites,
    passing_suites,
    blocked_suites,
  }
}

///|
/// Return the stable suite groups that the compatibility catalog exposes to CI.
///
/// Example:
/// let groups = suite_groups()
/// inspect(groups.length() > 0, content="true")
///
/// Notes:
/// - Group order follows first appearance in the catalog so markdown reports and CI job names remain stable.
/// - Current Phase 5 grouping is intentionally coarse: frontend-atn, runtime, cst, compatibility.
pub fn suite_groups() -> Array[String] {
  let groups : Array[String] = []
  for descriptor in compatibility_catalog() {
    append_unique(groups, descriptor.suite_group)
  }
  groups
}
