# cldr-conformance

[![ci](https://github.com/CCllff-jpg/cldr-conformance/actions/workflows/ci.yml/badge.svg)](https://github.com/CCllff-jpg/cldr-conformance/actions/workflows/ci.yml)

**CLDR conformance benchmark and differential tester for MoonBit i18n implementations.**

用 [CLDR](https://cldr.unicode.org/) 官方测试数据，度量并对比 MoonBit 生态里各个 i18n 实现的一致性：谁符合标准、差在哪个维度、差多少。

[![mooncakes](https://img.shields.io/badge/mooncakes-CCllff--jpg%2Fcldr--conformance-2ea44f)](https://mooncakes.io/details/CCllff-jpg/cldr-conformance)

> 状态：**已发布到 mooncakes.io（`CCllff-jpg/cldr-conformance@0.1.0`）**。
> CLDR 官方数据可按不可变 tag 拉取、离线校验并幂等重跑，已解析成 **4714 条用例**
> （数字 2625 / 日期 1752 / MF2 337）；执行引擎、失败归因与报告模型（JSON / Markdown）
> 均已接入，并已跑出**第一份真实一致率矩阵**（见 `首轮发现.md`）。

## 安装

```
moon add CCllff-jpg/cldr-conformance
```

作为库使用时，公开入口是根包的类型与 `Report` 模型：

```moonbit nocheck
///|
import {
  "CCllff-jpg/cldr-conformance" @conformance,
}

///|
let reasons = @conformance.FailReason::all() // 9 个归因类别
```

作为工具使用时，跑 CLI 即可（需要仓库内的 `fixtures/`）：

```
moon run cmd/conform -- --impls moonlocale,lampclaw-i18n,moon_l10n --format html > report.html
```

## 解决什么问题

MoonBit 生态已有多个 i18n 实现（`moonlocale`、`lampclaw/i18n`、`moon_l10n`、`moongettext` 等），各自实现了复数规则、数字与日期格式化，但没有任何工具能回答：**它们是否符合 CLDR 标准、彼此差在哪里。**

CLDR 官方公开了一致性测试数据（`common/testData/`，见 `DATA-SOURCES.md`），本项目把它变成可执行的基准。

## 范围（Scope）

- 读取 CLDR 官方测试数据，产出**可复现**的一致率矩阵与失败归因
- 通过可插拔适配器调用被测实现（一个适配器一个包）
- 输出 JSON / Markdown / 静态 HTML 报告

## 非目标（Non-goals）

- **不实现格式化算法**——不写 LDML pattern 引擎、不写复数规则求值器
- **不造新的 i18n 库**——不做翻译目录、不做消息运行时
- **不修改被测包源码**——只通过公开 API 调用，缺陷以 issue/PR 反馈上游
- **不追求"全绿"**——`unsupported` 与 `fail` 严格区分并如实记录

## 当前结构

```
cmd/fetch-data/     # 数据资产工具：--sync / --verify / 单文件下载（D2 已完成）
cmd/conform/        # 主 CLI：登记适配器、解析 --impls 并清点用例；执行与报告后续接入
cmd/report-site/    # 报告 JSON → 静态 HTML（D16+）
internal/source/    # 目录、下载、摘要、清单、离线校验、幂等同步（D2 已完成）
internal/corpus/    # TSV / JSON 测试数据解析（D3–D4）
internal/engine/    # 用例执行、归因、最小化（D5–D7）
internal/adapter/   # 适配器 trait 对象登记、能力校验与选择（M1）
adapters/           # 每个被测实现一个包，reference_null 用于引擎自测
fixtures/           # 官方测试数据快照 + SOURCES.json（来源与 SHA256）
```

## 快速开始

```bash
moon check --target all
moon test

# 数据管线（默认已入库，可直接离线校验）
moon run cmd/fetch-data -- --verify
# 需要重新拉取时（幂等：已是最新的文件会跳过）
moon run cmd/fetch-data -- --sync
```

套件枚举（下面的 `mbt check` 代码块会被 `moon test` 真实执行）：

```mbt check
///|
test {
  let suites = @cldr-conformance.Suite::all()
  assert_eq(suites.length(), 4)
  assert_eq(suites[0].label(), "decimal")
}
```

## 许可证

代码 Apache-2.0；CLDR 测试数据为 [Unicode License v3](https://www.unicode.org/license.txt)，数据基线、文件清单与第三方依赖许可证见 `DATA-SOURCES.md`。
