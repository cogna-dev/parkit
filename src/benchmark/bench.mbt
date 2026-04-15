// Copyright 2024 cogna-dev
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// A representative JSON payload used for benchmarking the parsec JSON parser.
let bench_input : String =
  #|[
  #|  {
  #|    "id": 1,
  #|    "name": "Alice",
  #|    "email": "alice@example.com",
  #|    "active": true,
  #|    "score": 98.6,
  #|    "tags": ["admin", "user"],
  #|    "address": {
  #|      "street": "123 Main St",
  #|      "city": "Springfield",
  #|      "zip": "62701"
  #|    }
  #|  },
  #|  {
  #|    "id": 2,
  #|    "name": "Bob",
  #|    "email": "bob@example.com",
  #|    "active": false,
  #|    "score": 74.2,
  #|    "tags": ["user"],
  #|    "address": {
  #|      "street": "456 Elm Ave",
  #|      "city": "Shelbyville",
  #|      "zip": "62565"
  #|    }
  #|  },
  #|  {
  #|    "id": 3,
  #|    "name": "Carol",
  #|    "email": "carol@example.com",
  #|    "active": true,
  #|    "score": 88.0,
  #|    "tags": ["moderator", "user"],
  #|    "address": {
  #|      "street": "789 Oak Blvd",
  #|      "city": "Capital City",
  #|      "zip": "62702"
  #|    }
  #|  }
  #|]

///|
/// Benchmark: parse a medium-sized JSON array with nested objects.
///
/// Run with: `moon bench`
test (b : @bench.T) {
  b.bench(name="json_parse", fn() { b.keep(@json.parse(bench_input)) })
}

///|
/// Benchmark: match an exact string tag.
test (b : @bench.T) {
  let p = @nom.tag("hello")
  let input = "hello world"
  b.bench(name="tag", fn() { b.keep(p.parse(input)) })
}

///|
/// Benchmark: parse digits with take_while1.
test (b : @bench.T) {
  let p = @nom.take_while1(@nom.is_digit)
  let input = "1234567890rest"
  b.bench(name="take_while1_digits", fn() { b.keep(p.parse(input)) })
}

///|
/// Benchmark: parse a comma-separated list of numbers.
test (b : @bench.T) {
  let p = @nom.separated_list0(@nom.tag(","), @nom.digit1())
  let input = "1,22,333,4444,55555"
  b.bench(name="separated_list0", fn() { b.keep(p.parse(input)) })
}
