///|
/// Structured strict-lowering errors returned by generated typed CST packages.
///
/// Example:
/// let error = SchemaVersionMismatch(1, 2)
/// ignore(error)
///
/// Notes:
/// - The variants describe public contract drift between a generated typed package and one generic CST document.
/// - Recovery artifacts are surfaced explicitly instead of being silently ignored.
pub(all) enum TcstLoweringError {
  SchemaVersionMismatch(Int, Int)
  GrammarFingerprintMismatch(String, String)
  RootRuleMismatch(String, String)
  NodeKindMismatch(String, String, @antlr_cst.CstNodeId)
  AlternativeMismatch(String, Array[Int], Int?, @antlr_cst.CstNodeId)
  RequiredChildMissing(String, Int, String, @antlr_cst.CstNodeId)
  TokenKindMismatch(String, String?, @antlr_cst.CstNodeId)
  CardinalityViolation(String, Int, String, Int, @antlr_cst.CstNodeId)
  RecoveryArtifactPresent(String, @antlr_cst.CstNodeId)
}
