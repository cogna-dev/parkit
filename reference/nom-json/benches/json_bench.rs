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

//! Criterion benchmarks for the Rust nom JSON parser.
//!
//! These benchmarks use the same inputs as the MoonBit benchmarks in
//! `src/benchmark/bench.mbt`, allowing a direct performance comparison.

use criterion::{black_box, criterion_group, criterion_main, Criterion};
use nom_json::parse;

/// The same 3-object JSON array used in `src/benchmark/bench.mbt`.
const BENCH_INPUT: &str = r#"[
  {
    "id": 1,
    "name": "Alice",
    "email": "alice@example.com",
    "active": true,
    "score": 98.6,
    "tags": ["admin", "user"],
    "address": {
      "street": "123 Main St",
      "city": "Springfield",
      "zip": "62701"
    }
  },
  {
    "id": 2,
    "name": "Bob",
    "email": "bob@example.com",
    "active": false,
    "score": 74.2,
    "tags": ["user"],
    "address": {
      "street": "456 Elm Ave",
      "city": "Shelbyville",
      "zip": "62565"
    }
  },
  {
    "id": 3,
    "name": "Carol",
    "email": "carol@example.com",
    "active": true,
    "score": 88.0,
    "tags": ["moderator", "user"],
    "address": {
      "street": "789 Oak Blvd",
      "city": "Capital City",
      "zip": "62702"
    }
  }
]"#;

fn bench_json_parse(c: &mut Criterion) {
    c.bench_function("json_parse", |b| {
        b.iter(|| parse(black_box(BENCH_INPUT)).unwrap())
    });
}

criterion_group!(benches, bench_json_parse);
criterion_main!(benches);
