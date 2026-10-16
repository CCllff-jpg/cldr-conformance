# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- In the toplevel directory, there is a `moon.mod` file listing module
  metadata.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when
  changes affect outputs, run `moon test --update` to refresh snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. For snapshot tests that record
  structured debugging output, derive `Debug` and use `debug_inspect`, rather
  than deriving `Show` for debugging. For solid, well-defined results (e.g.
  scientific computations), prefer assertion tests. You can use
  `moon coverage analyze > uncovered.log` to see which parts of your code are
  not covered by tests.

---

# 本项目接手须知（cldr-conformance）

> 给接手开发的 agent 的必读部分。上面模板内容仍然适用；本节是项目特有的约束与经验。

## 1. 先读什么

| 文件 | 内容 |
|---|---|
| `README.md` | 项目定位、Scope / Non-goals、快速开始 |
| `DESIGN.md` | 7 条关键设计取舍（**动架构前先读这个**） |
| `开发方案.md` | §3 技术方案（API 草案 / 适配器机制 / 归因规则）、**§4 迭代计划（当前排期与剩余功能 M1–M8）** |
| `DATA-SOURCES.md` | 数据来源、版本、许可证、逐文件 SHA256 |
| `SUBMISSION.md` | 参赛申报书（对外承诺，验收会对着它查完成度） |
| `核心贡献说明.md` | 回应初审意见：可比性契约 / 归因依据 / 对照实验（含可证伪性证据链） |
| `可比性映射.md` | 三家 i18n 库的**真实 API** 与契约的逐条对照（哪格可比、哪格不可比及原因） |

## 2. 现在做到哪、下一步做什么

- **已完成**：数据管线（D2）、用例模型（D3–D4，4714 条）、适配器契约与登记（M1）、
  执行引擎（M2）、失败归因与报告模型（M3）。
  归因对照实验：单一维度 **7445/7445**、复合维度 **6299/6299**（均为 100%）。
- **下一步**：`开发方案.md` §4.2 的 **M4（接第一个真实适配器，出第一份真实一致率矩阵）**。
  三家库的可比性逐条对照见 `可比性映射.md`——注意结论：日期骨架套件无人可比、
  数字只有 moonlocale 直接可比、MF2 只有 `lampclaw/i18n` 可比，而
  **`Zhouz-z/moon_l10n` 实现的是 ICU（不同标准）**，不可用 MF2 语法去判它。
  该文档另建议把「**复数类别选择**」升为一等套件（四个库都有对应 API）。
- 测试 127 个全绿；`moon run cmd/conform -- --attribution-matrix` 可复现归因对照实验。

## 3. 硬性约束（违反会被 CI 拦下或影响验收）

1. **不要改 `fixtures/` 下的官方数据**。它们是 CLDR 上游文件，SHA256 记录在
   `fixtures/SOURCES.json`；改动会让 `moon run cmd/fetch-data -- --verify` 失败。
2. **仓库里禁止出现本机绝对路径 / 用户目录**（Windows 盘符路径、`/Users/` 或
   `/home/` 下的家目录等）。CI 与 `.githooks/pre-commit` 双层拦截，命中即失败。
   ⚠️ 连**注释和文档里的示例**也算：直接写出「盘符 + 冒号 + 反斜杠」开头的字面量会被
   自己拦下，描述这类路径时请用文字说明或占位符（这一条就是踩过之后补的）。
3. **验收硬标准：项目必须发布到 mooncakes.io**。发布前确认 `moon.mod` 的命名空间与
   GitHub 账号一致（当前 `CCllff-jpg/cldr-conformance`）。
4. **解析上游数据时，遇到未建模字段或未知取值必须报错**，不要静默跳过——
   静默会把"数据基线变了"伪装成"测试通过"。

## 4. 开发流程（每完成一块）

```bash
moon fmt                    # 格式化
moon info                   # 更新 .mbti（有变更要一起提交）
moon check --target all     # 必须零警告
moon test                   # 必须全绿
moon run cmd/conform        # 端到端清点，确认没跑坏
```

然后提交。**中文** commit message，说明取舍并带上验证命令：

```
feat(engine): M2 执行引擎（异常隔离 + 超时）

- 单用例 raise 被隔离，一条崩不中断整轮
- ...

验证: moon check --target all 零警告; moon test 92/92
```

**不要 push**，除非用户明确要求推送。

## 5. MoonBit 踩坑清单（本项目已经踩过，别再踩一遍）

| 症状 | 原因与解法 |
|---|---|
| E0079 大量 `implicit_impl_as_method` 警告 | `derive(...)` / `pub impl` 必须配显式 `pub extend T with Trait::{methods}`，集中放在每个包的 `extends.mbt` |
| 类型未定义（4032） | 跨包类型在**类型标注位置**要写包前缀，如 `@conformance.DecimalCase`；结构体字面量里不用 |
| 具体 suberror 无法字符串插值 | 具体 suberror 不实现 `Show`；先上转到 `Error`（测试里有 `error_text(err : Error)` 辅助函数） |
| 排序结果不合直觉 | `Compare for String` 是**先比长度、再逐码元**（core `builtin/string.mbt`），`Array::sort()` 会把 `"en"` 排在 `"ar-SA"` 前；要字典序用 `sort_by(...)` |
| `ambiguous_block` 警告 | 单字段结构体字面量写 `{ x, }`（带尾逗号），不要写 `{ x }` |
| `ambiguous_braces` | 空 Map 写 `Map([])`，不要写 `Map = {}` |
| 非 native 目标下 `unused_package` 警告 | 包级写 `supported_targets = "+native"`，不要用 per-file `options(targets: ...)` |
| `async test` 报 4037 | 必须在 `for "wbtest"` 的 import 块里显式加 `moonbitlang/async` |
| 泛型函数解析错误（3002） | 写 `fn[T] f`，不是 `fn f[T]` |
| 用 `@json` 报 0071 警告 | 在 `moon.pkg` 里显式 import `"moonbitlang/core/json"` |
| `print` 未绑定（4021） | MoonBit 只有 `println` |
| 保留字 | `method`（0035）等不能用作字段名或函数名 |

## 6. 架构铁律

- **facade（根包）拥有公开数据模型；`internal/*` 可以 import facade；facade 绝不能
  import `internal/*`**（会成环）。
- 引擎只接受**已经加载好的 facade 类型用例**；"读文件 → 解析"由 CLI 编排。
- 适配器只通过被测包的**公开 API** 调用，不复制其源码。
