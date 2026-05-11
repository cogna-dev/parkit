///|
/// Immutable character cursor consumed by the Phase 2 lexer runtime.
pub struct CharStream {
  source : String
  index : Int
  line : Int
  column : Int
}

///|
/// Create a lexer char stream starting at offset 0, line 1, column 0.
///
/// Example:
/// let stream = CharStream::new("abc")
/// inspect(stream.offset(), content="0")
///
/// Notes:
/// - Offsets are 0-based code-unit indices, matching the frontend cursor model.
/// - Lines are 1-based and columns are 0-based to stay aligned with `SourcePos`.
pub fn CharStream::new(source : String) -> CharStream {
  { source, index: 0, line: 1, column: 0 }
}

///|
/// Return the current absolute 0-based offset.
///
/// Example:
/// let stream = CharStream::new("abc").advance_by(2)
/// inspect(stream.offset(), content="2")
///
/// Notes:
/// - The offset is measured in the same string index space used by the frontend parser.
pub fn CharStream::offset(self : CharStream) -> Int {
  self.index
}

///|
/// Return the current frontend-compatible source position.
///
/// Example:
/// let pos = CharStream::new("abc").position()
/// inspect(pos.line, content="1")
///
/// Notes:
/// - The returned position is suitable for `SourceSpan` construction.
pub fn CharStream::position(self : CharStream) -> @antlr.SourcePos {
  @antlr.SourcePos::new(self.index, self.line, self.column)
}

///|
/// Report whether the stream is currently at EOF.
///
/// Example:
/// let eof = CharStream::new("").is_eof()
/// inspect(eof, content="true")
///
/// Notes:
/// - EOF means `offset() >= source.length()`.
pub fn CharStream::is_eof(self : CharStream) -> Bool {
  self.index >= self.source.length()
}

///|
/// Peek the current character without consuming it.
///
/// Example:
/// let ch = CharStream::new("abc").peek_char()
/// inspect(ch is Some(_), content="true")
///
/// Notes:
/// - Returns `None` at EOF.
pub fn CharStream::peek_char(self : CharStream) -> Char? {
  if self.is_eof() {
    None
  } else {
    Some(self.source.get_char(self.index).unwrap())
  }
}

///|
/// Check whether the remaining stream starts with the exact text.
///
/// Example:
/// let ok = CharStream::new("hello").starts_with("he")
/// inspect(ok, content="true")
///
/// Notes:
/// - Matching is exact and case-sensitive.
pub fn CharStream::starts_with(self : CharStream, text : String) -> Bool {
  let len = text.length()
  if self.index + len > self.source.length() {
    return false
  }
  self.source[self.index:self.index + len].to_string() == text
}

///|
/// Advance by one character while updating line and column bookkeeping.
///
/// Example:
/// let next = CharStream::new("a").advance()
/// inspect(next.offset(), content="1")
///
/// Notes:
/// - Advancing at EOF is a no-op.
pub fn CharStream::advance(self : CharStream) -> CharStream {
  if self.is_eof() {
    return self
  }
  let c = self.source.get_char(self.index).unwrap()
  if c == '\n' {
    {
      source: self.source,
      index: self.index + 1,
      line: self.line + 1,
      column: 0,
    }
  } else {
    {
      source: self.source,
      index: self.index + 1,
      line: self.line,
      column: self.column + 1,
    }
  }
}

///|
/// Advance by up to `count` characters.
///
/// Example:
/// let next = CharStream::new("abc").advance_by(2)
/// inspect(next.offset(), content="2")
///
/// Notes:
/// - The stream stops early at EOF.
pub fn CharStream::advance_by(self : CharStream, count : Int) -> CharStream {
  let mut stream = self
  let mut remaining = count
  while remaining > 0 && !stream.is_eof() {
    stream = stream.advance()
    remaining = remaining - 1
  }
  stream
}

///|
/// Slice the original source using absolute offsets.
///
/// Example:
/// let text = CharStream::new("abc").slice(0, 2)
/// inspect(text, content="ab")
///
/// Notes:
/// - Offsets are interpreted in the original source coordinate space.
pub fn CharStream::slice(
  self : CharStream,
  start_offset : Int,
  end_offset : Int,
) -> String {
  self.source[start_offset:end_offset].to_string()
}
