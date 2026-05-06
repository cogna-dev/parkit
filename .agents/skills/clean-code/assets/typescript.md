# TypeScript Appendix

仅当当前切片是 TypeScript / JavaScript / React / Node 时再读取本附录。

## Focus Checks

- `index.ts` 或 barrel file 承担了业务逻辑
- 父模块只是在做单一路径转发或重复 re-export
- 同一概念同时保留 `foo.ts` 和 `foo/` 目录模块
- `export *`、宽导出或中间类型让调用方依赖了内部实现形状
- 旧服务文件、旧 barrel 或旧目录入口被清空成 `export {}` 之类的兼容空壳
- 导入依赖 `../../` 这类随目录深度变化的相对路径
- 单个文件同时混合编排、数据转换、IO、副作用和 UI 框架细节
- `any`、`unknown as`、裸 `string` / `number` 在核心路径无语义传播
- 文件或模块名由多个词拼接而成，但其中一部分只是重复父级语义
- 大型 `*.test.ts` / `*.spec.ts` 仍按时间堆积，而非按行为组织

## Instructions

1. 让 `index.ts` 和 barrel file 只做 re-export 或 facade，不承载业务逻辑。
2. 超长文件按能力拆分，名称保持局部语义；进入父目录后不再重复父级前缀。
3. 默认保持文件私有作用域，只导出 facade、领域类型和少量稳定常量。
4. 优先使用 `export type` 暴露纯类型；谨慎使用 `export *`，避免把内部结构变成公共契约。
5. 若项目已有根 alias，优先从稳定 alias 路径导入，例如 `@/foo/bar`，而不是 `../../bar` 这类目录爬升路径；若没有 alias，至少优先经过稳定 facade 或包入口，而不是把相对目录结构变成契约。
6. 删除父层浅包装，除非它确实在聚合多个子模块、隐藏路由策略或显著收敛入口。
7. 不把旧路径留成 `export {}`、空文件或无职责兼容层；若必须保留旧入口，至少让它承担明确的迁移或聚合职责，并在结果里写清为什么暂时不能删除。
8. 若文件或模块名包含多个词，先评估能否通过改名、下沉到父模块或继续拆分收敛为更短的名字；只有明显减少歧义时才保留多词命名。
9. 在边界层把 `fetch`、`axios`、数据库驱动、schema 校验等底层错误转换成领域错误。
10. 用判别联合、领域对象或更具体的接口替代核心路径里的裸原始类型和松散对象。
11. 白盒测试尽量共址；大型行为测试按 workflow、error family 或 input family 拆分。
12. 对稳定导出项补 TSDoc，至少写清用途、示例和注意事项。

## Validation

- 仓库既有 formatter
- 仓库既有 lint 或 typecheck
- 与切片最接近的单测或集成测试
- 若改动 React / 渲染层，额外跑一次 typecheck
- 若只能做到 typecheck，明确说明为什么当前切片缺少更接近行为的验证
