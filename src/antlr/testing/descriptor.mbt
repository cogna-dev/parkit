///|
pub enum CompatibilitySuiteKind {
  ContractSuite
  UpstreamMirrorSuite
}

///|
pub enum CompatibilityLayer {
  FrontendContract
  AtnContract
  RuntimeContract
  CstContract
  CompatibilityGovernance
}

///|
pub enum CompatibilityStatus {
  Planned
  Porting
  Passing
  Blocked
}

///|
pub struct CompatibilityDescriptor {
  suite_id : String
  suite_name : String
  suite_kind : CompatibilitySuiteKind
  suite_group : String
  layer : CompatibilityLayer
  status : CompatibilityStatus
  upstream_reference : String?
  evidence_command : String
  test_files : Array[String]
  resource_catalogs : Array[String]
  known_gap : String?
  blocked_reason : String?
}

///|
pub struct CompatibilitySummary {
  total_suites : Int
  planned_suites : Int
  porting_suites : Int
  passing_suites : Int
  blocked_suites : Int
}

///|
fn compatibility_suite_kind_name(kind : CompatibilitySuiteKind) -> String {
  match kind {
    ContractSuite => "contract"
    UpstreamMirrorSuite => "upstream-mirror"
  }
}

///|
fn compatibility_layer_name(layer : CompatibilityLayer) -> String {
  match layer {
    FrontendContract => "frontend"
    AtnContract => "atn"
    RuntimeContract => "runtime"
    CstContract => "cst"
    CompatibilityGovernance => "compatibility"
  }
}

///|
fn compatibility_status_name(status : CompatibilityStatus) -> String {
  match status {
    Planned => "planned"
    Porting => "porting"
    Passing => "passing"
    Blocked => "blocked"
  }
}
