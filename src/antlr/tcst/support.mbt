///|
/// Non-empty array wrapper used by generated typed CST fields for `+` cardinality.
///
/// Example:
/// let values = non_empty_from_array([1, 2])
/// inspect(values is Some(_), content="true")
///
/// Notes:
/// - The wrapper preserves lexical order through `head` and `tail`.
/// - The helper constructor returns `None` when the source array is empty.
pub(all) struct NonEmpty[T] {
  head : T
  tail : Array[T]
}

///|
/// Build one `NonEmpty[T]` from an array when at least one element exists.
///
/// Example:
/// let values = non_empty_from_array([1, 2])
/// inspect(values is Some(_), content="true")
///
/// Notes:
/// - The first array element becomes `head`.
/// - The remaining elements are copied into `tail` in source order.
pub fn[T] non_empty_from_array(values : Array[T]) -> NonEmpty[T]? {
  if values.length() == 0 {
    return None
  }
  let tail : Array[T] = []
  for index = 1; index < values.length(); index = index + 1 {
    tail.push(values[index])
  }
  Some({ head: values[0], tail })
}

///|
/// Shared token wrapper exposed by generated typed CST packages.
///
/// Example:
/// let token = terminal_token_from_record(record)
/// inspect(token.kind_id >= 0, content="true")
///
/// Notes:
/// - The wrapper keeps only stable token metadata required by typed CST consumers.
/// - Channel, mode, and recovery details remain available on the source generic CST document.
pub(all) struct TerminalToken {
  token_id : @antlr_cst.CstTokenId
  kind_id : Int
  lexeme : String
  span : @antlr.SourceSpan
}

///|
/// Project one public CST token record into the shared typed token wrapper.
///
/// Example:
/// let token = terminal_token_from_record(record)
/// inspect(token.lexeme.length() >= 0, content="true")
///
/// Notes:
/// - The token id is only stable within the originating `CstDocument`.
/// - Synthetic tokens are still represented here; strict lowering decides whether they are allowed.
pub fn terminal_token_from_record(
  record : @antlr_cst.CstTokenRecord,
) -> TerminalToken {
  {
    token_id: record.id,
    kind_id: record.token_kind_id,
    lexeme: record.lexeme,
    span: record.span,
  }
}
