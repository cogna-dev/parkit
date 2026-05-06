# Rust Appendix

仅当当前切片是 Rust / Cargo workspace 时再读取本附录。

## Focus Checks

- `mod.rs`、`lib.rs` 或 `main.rs` 堆积了业务实现，而不只是入口或 facade
- 大型 `impl` 同时承担编排、存储、解析、校验或序列化
- 父模块只是在做 `child::x()` 转发或重复 `pub use`
- 同一概念同时保留 `foo.rs` 和 `foo/` 目录模块
- `pub` / `pub(crate)` 扩散，让内部类型和中间态结构外泄
- 导入依赖 `use super::super::...` 这类脆弱的相对祖先路径
- 文件或模块名由多个词拼接而成，但其中一部分只是重复父级语义
- 大型测试文件远离实现，已难以按行为定位

## Instructions

1. 让 `mod.rs` 保持为模块声明、re-export 或 facade，不在入口层堆业务逻辑。
2. 大型 `impl` 按能力拆分为多个文件，如 `read.rs`、`write.rs`、`validate.rs`，但不要制造只有一层转发的薄壳。
3. 可见性按私有 → `pub(super)` → `pub(crate)` → `pub` 逐级放宽，只在真实跨边界需求出现时提升。
4. 导入优先使用 crate 根上的稳定路径，例如 `use crate::foo::bar`；避免 `use super::super::bar`，除非局部测试模块或语言边界使其不可避免。
5. 删除父层浅包装和重复 `pub use`，除非它们确实减少了调用方需要理解的入口数量。
6. 若文件或模块名包含多个词，先评估能否通过改名、下沉到父模块或继续拆分来压缩命名；只有明显减少歧义时才保留多词命名。
7. 用领域类型和领域错误替代裸 `String` / `usize` / `io::Error` 在模块边界横向传播。
8. 白盒测试优先放在 `#[cfg(test)] mod tests`；大型组合测试按 workflow 或 error domain 拆分。
9. 对稳定的 `pub` / `pub(crate)` API 补文档注释，至少写清用途、示例和注意事项。

## Validation

- `cargo fmt`
- `cargo clippy` 或仓库约定 lint
- 与切片最接近的 `cargo test`
- 若受 feature、workspace member 或 target 限制，明确说明验证范围
