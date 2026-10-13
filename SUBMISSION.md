# 2026 MoonBit 黑客松 · 十月赛 项目申报书

| 项 | 内容 |
|---|---|
| **项目名称** | cldr-conformance —— CLDR 一致性基准与差分对拍工具链 |
| **参赛者** | CCllff-jpg |
| **公开仓库** | <https://github.com/CCllff-jpg/cldr-conformance> |
| **项目类型** | 全新项目（新仓库、新 MoonBit 模块） |
| **赛事方向** | 开发者工具 / 工具库 |
| **许可证** | 代码 Apache-2.0；数据 Unicode License v3 |
| **申报日期** | 2026-10-13 |

---

## 一、要解决的真实问题

MoonBit 生态已有至少 5 个 i18n 实现（`moonlocale`、`lampclaw/i18n`、`moon_l10n`、`moongettext`、`moon-humanize`），
各自实现了复数规则、数字与日期格式化。但**没有任何工具能回答：它们是否符合 CLDR 标准、彼此差在哪里。**

实测证据：在 mooncakes.io 上 `moon search 'cldr'` 返回 **0 个结果**——一致性验证是完全空白的赛道，
而 CLDR 官方早已公开了权威一致性测试数据（`common/testData/`，含 4714 条用例）。

## 二、做什么（Scope）

读取 CLDR 官方测试数据 → 通过**可插拔适配器**调用被测实现 → 对拍并**自动归因失败原因** →
输出**可复现**的一致率矩阵与缺陷清单。

## 三、不做什么（Non-goals，写在 README 里）

- **不实现格式化算法**——不写 LDML pattern 引擎、不写复数规则求值器
- **不造新的 i18n 库**——不做翻译目录、不做消息运行时
- **不修改被测包源码**——只通过公开 API 调用，缺陷以最小可复现用例反馈上游
- **不追求"全绿"**——`unsupported`（实现没这个能力）与 `fail`（做错了）严格区分并如实记录

## 四、已完成的工作（截至 2026-10-13，12 个提交全部公开可查）

| 里程碑 | 产出 |
|---|---|
| **数据管线** | 按**不可变 tag** `release-49-beta3` 拉取 12 个 CLDR 官方文件（251 KB）；SHA256 清单；`--verify` 离线校验；幂等重跑（二次执行 12 个全部跳过） |
| **用例模型** | 把官方数据解析成 **4714 条可执行用例**：数字 2625、日期 1752（骨架 + 格式化）、MF2 337 |
| **工程质量** | **84 个测试全绿**；`moon check --target all` 零警告；CI 每次 push 跑检查 + 测试 + 离线校验 |
| **规模** | 源码 25 个文件 / 1673 行；测试 17 个文件 / 1192 行（合计 2865 行） |

**现在已经能跑给你看**：

```bash
git clone https://github.com/CCllff-jpg/cldr-conformance && cd cldr-conformance

moon test                                # 84/84 通过
moon run cmd/fetch-data -- --verify      # 离线校验 12 个官方文件，无需网络
moon run cmd/conform                     # 清点 4714 条用例
```

## 五、10 月 31 日前将交付

1. **执行引擎与失败归因**：分组 / 数字系统 / 舍入 / 复数词形 / 双向控制符 / 紧凑格式 六分类
2. **至少 3 个真实适配器的一致率矩阵**（`moonlocale`、`lampclaw/i18n`、`moon_l10n`）
3. **静态 HTML 报告**：一致率矩阵 + 归因分布 + 字节级对比 + RTL 控制符可视化
4. **给上游包的最小可复现缺陷用例与 issue**

## 七、合规与来源

- **代码**：Apache-2.0（见 `LICENSE`）
- **数据**：CLDR 官方测试数据，[Unicode License v3](https://www.unicode.org/license.txt)；
  来源、版本、SHA256 逐文件记录在 `DATA-SOURCES.md`
- **第三方依赖**：`moonbitlang/async@0.22.4`、`gmlewis/sha256@0.18.0`、`gmlewis/base64@0.16.13`，全部 Apache-2.0
