# cldr-conformance · 项目申报书

项目：CLDR 一致性基准与差分对拍工具 · 方向：开发者工具
仓库 `CCllff-jpg/cldr-conformance` · 发布 `CCllff-jpg/cldr-conformance@0.1.1` · 在线报告 `ccllff-jpg.github.io/cldr-conformance`
许可：代码 Apache-2.0，数据 Unicode License v3 · 原创项目，非移植、非二次开发

## 核心功能

1. **用例生成**：把 CLDR 官方测试数据解析成可执行用例，现有 10545 条，覆盖数字、日期、复数、消息格式四类。
2. **逐条对拍**：通过可插拔适配器只调用被测库的公开 API，比对实际输出与官方期望值。
3. **失败归因**：把失败归到 9 类可区分原因（分组符、数字系统、舍入、复数类别、双向控制符、紧凑格式、
   模式回退、数值错误、兜底），并给出字符级差异，指出"错在哪一位"。
4. **可比性控制**：按各库声明的能力决定哪些用例可比；没有的能力记 unsupported，不计入一致率。
5. **差分对比**：同一条用例列出不同实现之间的结论差异，回答"两个库差在哪里"。
6. **报告输出**：JSON / Markdown / 自包含 HTML 三种格式，含一致率矩阵、归因分布与失败样例。

## 实现方案

CLDR 数据按不可变 tag 拉取、逐文件 SHA256 校验，解析成用例模型；适配器调用被测库公开 API，
对拍后按规则归因，最后出报告。归因规则用错误注入对照实验验证：每种注入只破坏一个维度，
正确答案由构造决定，单一维度 7445 条、两处同时错 6299 条均可判对。

## 交付物

- 可 `moon add` 的工具库与 CLI（已发布 0.1.1）
- 三个真实库的一致率矩阵：moonlocale 数字 42%、复数 85%；moon_l10n 复数 83%；lampclaw/i18n 消息格式 80%
- 6 条带最小复现的缺陷反馈，其中 2 条已提交上游（`zlhahaha/moonlocale` [#1](https://github.com/zlhahaha/moonlocale/issues/1)、[#2](https://github.com/zlhahaha/moonlocale/issues/2)）
- 在线报告与可复现命令，一条命令重跑全部结果

## 工程与合规

142 个测试全绿，`moon check --target all` 零警告，CI 每次 push 跑检查与数据校验；
被测库只通过公开 API 调用、不改源码；仓库不含本机路径，数据来源与 SHA256 逐文件记录。
