# ANTLR Compatibility Statement

parkit 当前对 ANTLR 主线的兼容承诺，围绕 grammar -> normalized frontend -> GrammarAtn -> lexer runtime -> parser runtime -> versioned CstDocument 这条可验证链路，而不是 generated recognizer、listener、visitor 或 upstream object model 的逐项复制。

当前稳定承诺：

1. frontend、ATN、runtime、generic CST 都有独立 contract suite 与稳定 evidence command。
2. support matrix、suite catalog、CI 分组必须保持一致，不能只靠单个整仓测试总结果表达支持范围。
3. passing suite 的定义依赖 descriptor、测试入口和 evidence command 三者一致，而不是测试总数。

当前不承诺：

1. generated recognizer/listener/visitor parity。
2. upstream JUnit/Gradle harness 的逐文件镜像。
3. typed CST 扩展在主线 Phase 5 之前进入稳定支持面。

当前 suite 快照：total=25, passing=24, porting=0, planned=0, blocked=1.

当前唯一 blocked 项是 runtime-testsuite/Listeners，对应原因是主线公开树形面已经明确收口为 versioned CstDocument + query API，而不是 listener/visitor runtime。

所有 suite 与状态的单一事实来源是 src/antlr/data/testing/suites/catalog.tsv；support matrix 与 compatibility statement 都必须能从同一份 catalog 重新生成。