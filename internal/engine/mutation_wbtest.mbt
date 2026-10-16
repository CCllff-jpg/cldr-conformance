///|
/// 每种注入都有一个**孤立的**样例：字符串只在这一个维度上不同，
/// 因此正确答案是构造出来的，不依赖主观判断。
test "孤立样例：每种注入都被还原成预定原因" {
  let samples : Array[(MutationKind, String, String)] = [
    (DropGrouping, "1,234", "1234"),
    (DropDecimalPoint, "1.2", "12"),
    (SwapGroupingGlyph, "1,234", "1.234"),
    (SwapDigitSystem, "1234", "١٢٣٤"),
    (DropBidiMarks, "\u{200E}1,234", "1,234"),
    (PluralizeWord, "1 message", "1 messages"),
    (ChangeCompactForm, "1.2K", "1.2Kx"),
    (ReturnPattern, "1,234", "#,##0.###"),
  ]
  for sample in samples {
    let (kind, expected, actual) = sample
    assert_eq(mutate(kind, expected), Some(actual))
    assert_eq(
      attribute(kind.context(), expected, actual),
      kind.intended_reason(),
    )
  }
}

///|
/// 不适用的注入必须返回 `None`，而不是硬造一个输出——
/// 对照组一旦混入不真实的样本，还原率就没有意义。
test "不适用的注入返回 None" {
  assert_eq(mutate(DropGrouping, "1234"), None)
  assert_eq(mutate(DropBidiMarks, "1234"), None)
  assert_eq(mutate(PluralizeWord, "1234"), None)
  assert_eq(mutate(ChangeCompactForm, "1234"), None)
  // 分隔符后跟 3 位数字时分组与小数点无法区分 → 不注入
  assert_eq(mutate(DropDecimalPoint, "1,234"), None)
  assert_eq(mutate(ReturnPattern, ""), None)
}

///|
test "注入必须真的改变字符串（否则对照组会自我抵消）" {
  for kind in MutationKind::all() {
    assert_true(mutate(kind, "1,234.5") != Some("1,234.5"))
  }
}

///|
/// 对照实验的可证伪性：在真实 CLDR 期望值上注入错误，看归因能否还原。
///
/// 实测基线（数据集钉在不可变 tag 上，因此这些数字可复现）：
/// 八类注入、8006 个样本，**全部还原**。任何一条规则被改坏，这里会立刻掉下来。
async test "真实语料对照实验：每类注入的还原率必须保持满值" {
  let decimal = @corpus.decimal_corpus_from_tsv(
    @fs.read_file("fixtures/decimal/decimals.tsv").text(),
  )
  let expected_values = decimal.cases.map(case => case.expected)
  let outcomes = mutation_matrix(expected_values)
  let mut applied_total = 0
  for outcome in outcomes {
    applied_total += outcome.applied
    if outcome.applied > 0 {
      assert_eq(outcome.accuracy_text(), "100%")
    }
  }
  // 语料必须真的能让多数注入生效，否则这个实验是空的
  assert_true(applied_total > 500)
}

///|
test "对照实验矩阵可渲染为 Markdown" {
  let outcomes = mutation_matrix(["1,234", "1.2", "1234"])
  let markdown = render_mutation_matrix(outcomes)
  assert_true(
    markdown.contains("| 注入（只破坏一个维度） | 预定原因 |"),
  )
  assert_true(markdown.contains("drop-grouping"))
  assert_true(markdown.contains("总体还原率"))
}

///|
/// 诊断用：打印各类注入的未命中样例（用于定位规则缺陷，不参与断言）。
async test "诊断：未命中样例" {
  let decimal = @corpus.decimal_corpus_from_tsv(
    @fs.read_file("fixtures/decimal/decimals_modern_locales.tsv").text(),
  )
  for kind in MutationKind::all() {
    let mut shown = 0
    for case in decimal.cases {
      match mutate(kind, case.expected) {
        None => ()
        Some(actual) =>
          if actual != case.expected {
            let reason = attribute(kind.context(), case.expected, actual)
            if reason != kind.intended_reason() && shown < 3 {
              println(
                "MISS \{kind.label()}: expected=[\{case.expected}] actual=[\{actual}] got=\{reason.label()}",
              )
              shown += 1
            }
          }
      }
    }
  }
}
