///|
/// Severity attached to a frontend diagnostic.
pub(all) enum DiagnosticSeverity {
  ErrorSeverity
  WarningSeverity
}

///|
/// A 0-based source position.
pub struct SourcePos {
  offset : Int
  line : Int
  column : Int
}

///|
pub fn SourcePos::new(offset : Int, line : Int, column : Int) -> SourcePos {
  { offset, line, column }
}

///|
/// Half-open span in the source text.
pub struct SourceSpan {
  start : SourcePos
  end : SourcePos
}

///|
pub fn SourceSpan::new(start : SourcePos, end : SourcePos) -> SourceSpan {
  { start, end }
}

///|
pub fn SourceSpan::point(pos : SourcePos) -> SourceSpan {
  { start: pos, end: pos }
}

///|
/// Structured syntax or semantic diagnostic.
pub struct Diagnostic {
  severity : DiagnosticSeverity
  message : String
  span : SourceSpan
}

///|
pub fn Diagnostic::new(
  severity : DiagnosticSeverity,
  message : String,
  span : SourceSpan,
) -> Diagnostic {
  { severity, message, span }
}

///|
pub fn Diagnostic::error(message : String, span : SourceSpan) -> Diagnostic {
  { severity: ErrorSeverity, message, span }
}

///|
pub fn Diagnostic::warning(message : String, span : SourceSpan) -> Diagnostic {
  { severity: WarningSeverity, message, span }
}

///|
pub fn diagnostic_severity_name(severity : DiagnosticSeverity) -> String {
  match severity {
    ErrorSeverity => "error"
    WarningSeverity => "warning"
  }
}
