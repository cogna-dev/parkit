///|
/// Immutable parser-facing token stream built on top of Phase 2 lexer tokens.
pub struct ParserTokenStream {
  tokens : Array[LexerToken]
  visible_indices : Array[Int]
  visible_offset : Int
  default_channel_name : String
}

///|
fn parser_copy_visible_indices(values : Array[Int]) -> Array[Int] {
  let copied : Array[Int] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn parser_visible_indices_for_tokens(
  tokens : Array[LexerToken],
  default_channel_name : String,
) -> Array[Int] {
  let visible_indices : Array[Int] = []
  for index = 0; index < tokens.length(); index = index + 1 {
    let token = tokens[index]
    if token.is_eof || token.channel_name == default_channel_name {
      visible_indices.push(index)
    }
  }
  visible_indices
}

///|
fn parser_visible_cursor_index(
  stream : ParserTokenStream,
  lookahead : Int,
) -> Int {
  if stream.visible_indices.length() == 0 {
    abort("parser token stream requires at least one visible token")
  }
  let wanted = stream.visible_offset + lookahead - 1
  if wanted < stream.visible_indices.length() {
    wanted
  } else {
    stream.visible_indices.length() - 1
  }
}

///|
fn parser_visible_token(
  stream : ParserTokenStream,
  lookahead : Int,
) -> LexerToken {
  let cursor = parser_visible_cursor_index(stream, lookahead)
  stream.tokens[stream.visible_indices[cursor]]
}

///|
/// Build a parser token stream from the full Phase 2 lexer token table.
///
/// Example:
/// let stream = ParserTokenStream::new(result.tokens)
/// inspect(stream.visible_offset(), content="0")
///
/// Notes:
/// - Only tokens on `DEFAULT_TOKEN_CHANNEL` plus EOF are visible to parser prediction.
/// - Hidden/off-channel tokens remain preserved on `tokens` for later CST/trivia work.
pub fn ParserTokenStream::new(tokens : Array[LexerToken]) -> ParserTokenStream {
  let default_channel_name = "DEFAULT_TOKEN_CHANNEL"
  {
    tokens,
    visible_indices: parser_visible_indices_for_tokens(
      tokens, default_channel_name,
    ),
    visible_offset: 0,
    default_channel_name,
  }
}

///|
/// Return the current 0-based visible-token cursor.
///
/// Example:
/// let offset = ParserTokenStream::new(result.tokens).visible_offset()
/// inspect(offset, content="0")
///
/// Notes:
/// - This offset advances only over parser-visible tokens, not over the full token table.
pub fn ParserTokenStream::visible_offset(self : ParserTokenStream) -> Int {
  self.visible_offset
}

///|
/// Return the total number of parser-visible tokens, including EOF.
///
/// Example:
/// let count = ParserTokenStream::new(result.tokens).visible_count()
/// inspect(count > 0, content="true")
///
/// Notes:
/// - EOF is always counted when present in the input token table.
pub fn ParserTokenStream::visible_count(self : ParserTokenStream) -> Int {
  self.visible_indices.length()
}

///|
/// Look ahead `k` visible tokens and return the token record.
///
/// Example:
/// let token = ParserTokenStream::new(result.tokens).lt(1)
/// inspect(token.is_eof, content="false")
///
/// Notes:
/// - Lookahead is 1-based.
/// - Requests beyond EOF clamp to the final EOF token.
pub fn ParserTokenStream::lt(
  self : ParserTokenStream,
  lookahead : Int,
) -> LexerToken {
  parser_visible_token(self, lookahead)
}

///|
/// Look ahead `k` visible tokens and return the symbolic token name.
///
/// Example:
/// let name = ParserTokenStream::new(result.tokens).la(1)
/// inspect(name.length() > 0, content="true")
///
/// Notes:
/// - This is a convenience wrapper over `lt(k).token_name`.
pub fn ParserTokenStream::la(
  self : ParserTokenStream,
  lookahead : Int,
) -> String {
  self.lt(lookahead).token_name
}

///|
/// Advance by one visible token.
///
/// Example:
/// let next = ParserTokenStream::new(result.tokens).consume()
/// inspect(next.visible_offset(), content="1")
///
/// Notes:
/// - Consuming at EOF is a no-op.
pub fn ParserTokenStream::consume(
  self : ParserTokenStream,
) -> ParserTokenStream {
  if self.is_eof() {
    self
  } else {
    {
      tokens: self.tokens,
      visible_indices: parser_copy_visible_indices(self.visible_indices),
      visible_offset: self.visible_offset + 1,
      default_channel_name: self.default_channel_name,
    }
  }
}

///|
/// Advance by up to `count` visible tokens.
///
/// Example:
/// let next = ParserTokenStream::new(result.tokens).advance_by(2)
/// inspect(next.visible_offset(), content="2")
///
/// Notes:
/// - The stream stops early at EOF.
pub fn ParserTokenStream::advance_by(
  self : ParserTokenStream,
  count : Int,
) -> ParserTokenStream {
  let mut stream = self
  let mut remaining = count
  while remaining > 0 && !stream.is_eof() {
    stream = stream.consume()
    remaining = remaining - 1
  }
  stream
}

///|
/// Report whether the visible cursor currently points at EOF.
///
/// Example:
/// let eof = ParserTokenStream::new(result.tokens).is_eof()
/// inspect(eof, content="false")
///
/// Notes:
/// - Off-channel tokens do not affect the visible EOF check.
pub fn ParserTokenStream::is_eof(self : ParserTokenStream) -> Bool {
  self.lt(1).is_eof
}
