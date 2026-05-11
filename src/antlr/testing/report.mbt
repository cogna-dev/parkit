///|
fn optional_text(value : String?) -> String {
  match value {
    Some(text) => text
    None => "-"
  }
}

///|
fn list_text(values : Array[String]) -> String {
  if values.length() == 0 {
    "-"
  } else {
    values.join(", ")
  }
}

///|
fn append_row(
  lines : Array[String],
  descriptor : CompatibilityDescriptor,
) -> Unit {
  lines.push(
    "| " +
    descriptor.suite_id +
    " | " +
    compatibility_suite_kind_name(descriptor.suite_kind) +
    " | " +
    descriptor.suite_group +
    " | " +
    compatibility_layer_name(descriptor.layer) +
    " | " +
    descriptor.suite_name +
    " | " +
    compatibility_status_name(descriptor.status) +
    " | " +
    descriptor.evidence_command +
    " | " +
    list_text(descriptor.test_files) +
    " | " +
    list_text(descriptor.resource_catalogs) +
    " | " +
    optional_text(descriptor.known_gap) +
    " | " +
    optional_text(descriptor.blocked_reason) +
    " |",
  )
}

///|
fn render_contract_table(lines : Array[String]) -> Unit {
  lines.push("## Repo-Local Contract Suites")
  lines.push("")
  lines.push(
    "| Suite ID | Kind | Group | Layer | Name | Status | Evidence Command | Tests | Resource Catalogs | Known Gap | Blocked Reason |",
  )
  lines.push(
    "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
  )
  for descriptor in compatibility_catalog() {
    match descriptor.suite_kind {
      ContractSuite => append_row(lines, descriptor)
      UpstreamMirrorSuite => ()
    }
  }
}

///|
fn append_upstream_row(
  lines : Array[String],
  descriptor : CompatibilityDescriptor,
) -> Unit {
  lines.push(
    "| " +
    descriptor.suite_id +
    " | " +
    compatibility_suite_kind_name(descriptor.suite_kind) +
    " | " +
    descriptor.suite_group +
    " | " +
    compatibility_layer_name(descriptor.layer) +
    " | " +
    optional_text(descriptor.upstream_reference) +
    " | " +
    descriptor.suite_name +
    " | " +
    compatibility_status_name(descriptor.status) +
    " | " +
    descriptor.evidence_command +
    " | " +
    list_text(descriptor.test_files) +
    " | " +
    optional_text(descriptor.known_gap) +
    " | " +
    optional_text(descriptor.blocked_reason) +
    " |",
  )
}

///|
fn render_upstream_table(lines : Array[String]) -> Unit {
  lines.push("")
  lines.push("## Upstream Mirror Suites")
  lines.push("")
  lines.push(
    "| Suite ID | Kind | Group | Layer | Upstream Reference | Name | Status | Evidence Command | Tests | Known Gap | Blocked Reason |",
  )
  lines.push(
    "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
  )
  for descriptor in compatibility_catalog() {
    match descriptor.suite_kind {
      ContractSuite => ()
      UpstreamMirrorSuite => append_upstream_row(lines, descriptor)
    }
  }
}

///|
/// Render the repository support matrix as deterministic Markdown.
///
/// Example:
/// let report = render_support_matrix()
/// inspect(report.has_prefix("# ANTLR Support Matrix"), content="true")
///
/// Notes:
/// - The output is derived from `compatibility_catalog()` so the support matrix can be regenerated after any suite-status change.
/// - The matrix keeps repo-local contract suites separate from upstream mirrors to avoid overstating one-to-one upstream harness parity.
pub fn render_support_matrix() -> String {
  let summary = compatibility_summary()
  let lines : Array[String] = [
    "# ANTLR Support Matrix",
    "",
    "当前矩阵把仓库级 contract suite 与 upstream mirror suite 分开陈述，避免把本地 public-contract 断言误写成一对一 upstream harness parity。",
    "",
    "当前 suite 统计：total=" +
    summary.total_suites.to_string() +
    ", passing=" +
    summary.passing_suites.to_string() +
    ", porting=" +
    summary.porting_suites.to_string() +
    ", planned=" +
    summary.planned_suites.to_string() +
    ", blocked=" +
    summary.blocked_suites.to_string(),
    "",
  ]
  render_contract_table(lines)
  render_upstream_table(lines)
  lines.join("\n")
}

///|
/// Render the repository compatibility statement as deterministic Markdown.
///
/// Example:
/// let statement = render_compatibility_statement()
/// inspect(statement.has_prefix("# ANTLR Compatibility Statement"), content="true")
///
/// Notes:
/// - This statement deliberately describes behavior surfaces and evidence rules rather than internal implementation details.
/// - Generated recognizer parity, listener parity, and typed CST remain outside the current mainline compatibility promise.
pub fn render_compatibility_statement() -> String {
  let summary = compatibility_summary()
  [
    "# ANTLR Compatibility Statement",
    "",
    "parkit 当前对 ANTLR 主线的兼容承诺，围绕 grammar -> normalized frontend -> GrammarAtn -> lexer runtime -> parser runtime -> versioned CstDocument 这条可验证链路，而不是 generated recognizer、listener、visitor 或 upstream object model 的逐项复制。",
    "",
    "当前稳定承诺：",
    "",
    "1. frontend、ATN、runtime、generic CST 都有独立 contract suite 与稳定 evidence command。",
    "2. support matrix、suite catalog、CI 分组必须保持一致，不能只靠单个整仓测试总结果表达支持范围。",
    "3. passing suite 的定义依赖 descriptor、测试入口和 evidence command 三者一致，而不是测试总数。",
    "",
    "当前不承诺：",
    "",
    "1. generated recognizer/listener/visitor parity。",
    "2. upstream JUnit/Gradle harness 的逐文件镜像。",
    "3. typed CST 扩展在主线 Phase 5 之前进入稳定支持面。",
    "",
    "当前 suite 快照：total=" +
    summary.total_suites.to_string() +
    ", passing=" +
    summary.passing_suites.to_string() +
    ", porting=" +
    summary.porting_suites.to_string() +
    ", planned=" +
    summary.planned_suites.to_string() +
    ", blocked=" +
    summary.blocked_suites.to_string() +
    ".",
    "",
    "当前唯一 blocked 项是 runtime-testsuite/Listeners，对应原因是主线公开树形面已经明确收口为 versioned CstDocument + query API，而不是 listener/visitor runtime。",
    "",
    "所有 suite 与状态的单一事实来源是 src/antlr/data/testing/suites/catalog.tsv；support matrix 与 compatibility statement 都必须能从同一份 catalog 重新生成。",
  ].join("\n")
}
