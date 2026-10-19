MF2：未知函数 / 未解析变量 / 标记应按回退语义渲染，当前直接报错

**版本**：`lampclaw/i18n@0.9.3`
**严重性**：中（CLDR MF2 套件 337 条里 **64 条**受影响，占 19%）
**发现方式**：用 CLDR 官方 MF2 测试数据（`release-49-beta3`，`messageFormat/tests/*.json`）对拍。

## 现象

CLDR 的 MF2 测试数据里，有 64 条用例期望**照常输出文本**（其中大部分期望**空字符串**），
而实现返回了错误。按期望输出的形态分组：

| 期望输出 | 条数 | 实现报出的错误 |
|---|---|---|
| `hello {$place}`（未解析变量回退为原文） | 12 | `unresolved-variable` |
| `{$x}`（未知函数回退为变量 fallback） | 10 | `unknown-function` |
| `{\|a\|}`（字面量） | 4 | `unknown-function` |
| 空字符串（标记 `{#tag}` 渲染为空、`.input{$x}{{}}` 等） | 38 | `unknown-function, bad-selector` 等 |

## 最小复现

```moonbit
let ctx = @mf2.Mf2FormattingContext::new(locale="en").unwrap()
let r = @mf2.format_mf2_standalone("hello {$place}", ctx)   // 无参数
// 实际: r.errors = [unresolved-variable]，r.value 不完整
// CLDR 期望: "hello {$place}"（未解析变量回退为源文本）

let r2 = @mf2.format_mf2_standalone("{$x :f}", ctx)          // :f 未注册
// 实际: errors = [unknown-function]
// CLDR 期望: "{$x}"（未知函数回退为变量的 fallback）

let r3 = @mf2.format_mf2_standalone("{:u:f}", ctx)
// 实际: errors = [unknown-function]
// CLDR 期望: "{:u:f}"（无法解析的表达式整体回退为源文本）

let r4 = @mf2.format_mf2_standalone("{#tag}", ctx)
// 实际: errors = [unknown-function, bad-selector]
// CLDR 期望: ""（标记不产生输出）
```

## 依据

MF2 规范的 fallback 语义：表达式无法解析或解析失败时，按其 **fallback** 渲染后继续格式化，
而不是让整条消息失败。fallback 的取值顺序大致是：显式 fallback（`{{...}}`）→
变量名 / 源文本。标记（markup）则**不产生输出文本**。

## 建议

区分「诊断」与「结果」：`errors` 继续记录（对开发者很有用，本项目的对拍就靠它），
但 `value` 应按上述回退语义渲染；或提供一个 `strict` 开关，默认走规范行为。

顺带说明：**未解析变量的诊断本身是对的**（规范也要求产生解析错误），
差的只是"出错后仍要给出回退渲染结果"这一步。

## 影响面

CLDR MF2 套件 337 条中 64 条因此失败。在本项目的归因里这 64 条被标为
`unexpected-error`（"规范要求输出文本，实现却报错"），另有 2 条标为
`message-text-mismatch`（输出内容不同，与双向隔离符有关，另行报告）。