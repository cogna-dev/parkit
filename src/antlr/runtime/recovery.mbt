///|
/// Stable recovery projection kinds exposed for Phase 4 CST construction.
pub(all) enum ParserRecoveryProjectionKind {
  InsertedTokenProjection
  UnexpectedTokenProjection
  MissingSubtreeProjection
  RecoveryFenceProjection
}

///|
/// One projected parser recovery artifact ready for CST integration.
pub struct ParserRecoveryProjection {
  public_kind : ParserRecoveryProjectionKind
  detail_kind : String
  token_index : Int?
  token_name : String?
  visible_offset : Int
  span : @antlr.SourceSpan
  message : String
  requires_synthetic_token : Bool
}

///|
fn parser_recovery_projection_detail(kind : ParserRecoveryKind) -> String {
  match kind {
    UnexpectedToken => "unexpected-token"
    DeletedToken => "deleted-token"
    InsertedToken => "inserted-token"
    RecoveryFence => "recovery-fence"
  }
}

///|
/// Project one parser recovery record into the Phase 4 CST-facing error surface.
///
/// Example:
/// let projected = project_parser_recovery({ kind: UnexpectedToken, token_index: None, token_name: None, message: "oops", visible_offset: 0, span: @antlr.SourceSpan::point(@antlr.SourcePosition::new(0, 1, 1)) })
/// inspect(projected.detail_kind, content="unexpected-token")
///
/// Notes:
/// - Deleted-token recovery maps to the public unexpected-token class while preserving a more specific `detail_kind`.
/// - Inserted-token recovery requests a synthetic token record so generic CST can distinguish recovered tokens from original lexer output.
pub fn project_parser_recovery(
  event : ParserRecoveryEvent,
) -> ParserRecoveryProjection {
  let public_kind = match event.kind {
    InsertedToken => InsertedTokenProjection
    UnexpectedToken => UnexpectedTokenProjection
    DeletedToken => UnexpectedTokenProjection
    RecoveryFence => RecoveryFenceProjection
  }
  {
    public_kind,
    detail_kind: parser_recovery_projection_detail(event.kind),
    token_index: event.token_index,
    token_name: event.token_name,
    visible_offset: event.visible_offset,
    span: event.span,
    message: event.message,
    requires_synthetic_token: match event.kind {
      InsertedToken => true
      _ => false
    },
  }
}

///|
/// Project all parser recovery records into the CST-facing recovery surface.
///
/// Example:
/// let projected = project_parser_recoveries([])
/// inspect(projected.length(), content="0")
///
/// Notes:
/// - The output order matches the parser runtime recovery order.
/// - Callers can safely build deterministic snapshot baselines from the projected sequence.
pub fn project_parser_recoveries(
  events : Array[ParserRecoveryEvent],
) -> Array[ParserRecoveryProjection] {
  let projected : Array[ParserRecoveryProjection] = []
  for event in events {
    projected.push(project_parser_recovery(event))
  }
  projected
}
