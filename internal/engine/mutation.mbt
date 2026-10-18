///|
/// 已知的**错误注入**种类。
///
/// 用途：给失败归因构造**可证伪的对照组**。每种注入只破坏一个维度
/// （分组、数字系统、小数点、双向控制符、复数词形、紧凑缩写、模式语法），
/// 因此"正确答案"是**由构造决定**的，不依赖任何人的主观判断。
///
/// 这样归因就从"看着像启发式"变成可度量的命题：
/// 在 N 个只差一个维度的案例上，归因能否还原出预定原因、错判又去了哪里。
pub(all) enum MutationKind {
  /// 删掉分组分隔符：`1,234` → `1234`
  DropGrouping
  /// 删掉小数点：`1.2` → `12`
  DropDecimalPoint
  /// 分组符换成另一区域的字符：`1,234` → `1.234`
  SwapGroupingGlyph
  /// 数字系统换成阿拉伯-印度数字：`1234` → `١٢٣٤`
  SwapDigitSystem
  /// 删掉双向控制符：`\u{200E}1,234` → `1,234`
  DropBidiMarks
  /// 词形变化（复数类别不同）：`1 message` → `1 messages`
  PluralizeWord
  /// 紧凑缩写写错：`1.2K` → `1.2Kx`
  ChangeCompactForm
  /// 直接返回未展开的模式：→ `#,##0.###`
  ReturnPattern
} derive(Debug, Eq)

///|
/// 该注入**预定**应当被归到哪个原因。这是对照组的标准答案。
pub fn MutationKind::intended_reason(
  self : MutationKind,
) -> @conformance.FailReason {
  match self {
    DropGrouping => @conformance.FailReason::GroupingMismatch
    DropDecimalPoint => @conformance.FailReason::RoundingMismatch
    SwapGroupingGlyph => @conformance.FailReason::GroupingMismatch
    SwapDigitSystem => @conformance.FailReason::DigitSystemMismatch
    DropBidiMarks => @conformance.FailReason::BidiControlMissing
    PluralizeWord => @conformance.FailReason::PluralCategoryMismatch
    ChangeCompactForm => @conformance.FailReason::CompactFormMismatch
    ReturnPattern => @conformance.FailReason::PatternSyntaxUnsupported
  }
}

///|
pub fn MutationKind::label(self : MutationKind) -> String {
  match self {
    DropGrouping => "drop-grouping"
    DropDecimalPoint => "drop-decimal-point"
    SwapGroupingGlyph => "swap-grouping-glyph"
    SwapDigitSystem => "swap-digit-system"
    DropBidiMarks => "drop-bidi-marks"
    PluralizeWord => "pluralize-word"
    ChangeCompactForm => "change-compact-form"
    ReturnPattern => "return-pattern"
  }
}

///|
/// 全部注入种类，顺序即矩阵中的展示顺序。
pub fn MutationKind::all() -> Array[MutationKind] {
  [
    DropGrouping,
    DropDecimalPoint,
    SwapGroupingGlyph,
    SwapDigitSystem,
    DropBidiMarks,
    PluralizeWord,
    ChangeCompactForm,
    ReturnPattern,
  ]
}

///|
/// 该注入需要的归因上下文（紧凑用例与复数用例走不同分支）。
pub fn MutationKind::context(self : MutationKind) -> AttributionContext {
  match self {
    ChangeCompactForm =>
      AttributionContext::new(@conformance.Suite::Decimal, compact=true)
    PluralizeWord => AttributionContext::new(@conformance.Suite::MessageFormat2)
    _ => AttributionContext::new(@conformance.Suite::Decimal)
  }
}

///|
fn is_ascii_letter(unit : Int32) -> Bool {
  (unit >= 0x0041 && unit <= 0x005A) || (unit >= 0x0061 && unit <= 0x007A)
}

///|
/// 阿拉伯-印度数字的字面量（用字面量而不是 `Char::from_int`：
/// 后者在 core 中已废弃，会产生构建警告）。
fn arabic_digit_strings() -> Array[String] {
  ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]
}

///|
fn contains_index(indexes : Array[Int32], target : Int32) -> Bool {
  for index in indexes {
    if index == target {
      return true
    }
  }
  false
}

///|
/// 拷贝 `[start, end)` 区间（半开）。
fn copy_range(
  out : StringBuilder,
  text : String,
  start : Int32,
  end : Int32,
) -> Unit {
  // 注意：`StringBuilder::write_substring` 的第 3、4 个参数是 **(start, length)**
  // 而不是 (start, end)——见 core `builtin/string_methods.mbt`。
  // 这里踩过一次：传成 (start, end) 会把字符串拼错，注入样本全废。
  if end > start {
    out.write_substring(text, start, end - start)
  }
}

///|
/// 找出所有**分组分隔符**的下标：其后正好跟 3 个数字，且之后是分隔符或串尾。
fn grouping_indexes(text : String) -> Array[Int32] {
  let indexes : Array[Int32] = []
  let mut index = 0
  while index < text.length() {
    if is_separator(unit_at(text, index)) {
      let mut digits = 0
      let mut cursor = index + 1
      while cursor < text.length() &&
            digit_value(unit_at(text, cursor)) is Some(_) {
        digits += 1
        cursor += 1
      }
      if digits == 3 &&
        (cursor >= text.length() || is_separator(unit_at(text, cursor))) {
        indexes.push(index)
      }
    }
    index += 1
  }
  indexes
}

///|
/// 删除指定下标处的码元。
fn drop_at(text : String, skip : Array[Int32]) -> String {
  let out = StringBuilder()
  let mut run_start = 0
  let mut index = 0
  while index < text.length() {
    if contains_index(skip, index) {
      copy_range(out, text, run_start, index)
      run_start = index + 1
    }
    index += 1
  }
  copy_range(out, text, run_start, text.length())
  out.to_string()
}

///|
/// 删掉分组分隔符：`1,234,567` → `1234567`。
fn drop_grouping(text : String) -> String? {
  let indexes = grouping_indexes(text)
  if indexes.length() == 0 {
    return None
  }
  Some(drop_at(text, indexes))
}

///|
/// 删掉小数点：`1.2` → `12`。
///
/// 只处理"最后一个分隔符后面跟 1–2 位数字"的形状；跟着 3 位数字时分组与小数点
/// 无法区分（如德语 `1.234`），此时**不注入**而不是猜。
fn drop_decimal_point(text : String) -> String? {
  let mut index = 0
  let mut last = -1
  while index < text.length() {
    if is_separator(unit_at(text, index)) {
      last = index
    }
    index += 1
  }
  if last <= 0 {
    return None
  }
  let mut digits = 0
  let mut cursor = last + 1
  while cursor < text.length() && digit_value(unit_at(text, cursor)) is Some(_) {
    digits += 1
    cursor += 1
  }
  if digits < 1 || digits > 2 || cursor != text.length() {
    return None
  }
  let skip : Array[Int32] = [last]
  Some(drop_at(text, skip))
}

///|
/// 分组符换成另一区域的字符：`1,234` → `1.234`（逗号与句点互换）。
fn swap_grouping_glyph(text : String) -> String? {
  let indexes = grouping_indexes(text)
  if indexes.length() == 0 {
    return None
  }
  let out = StringBuilder()
  let mut run_start = 0
  let mut index = 0
  while index < text.length() {
    if contains_index(indexes, index) {
      copy_range(out, text, run_start, index)
      out.write_string(if unit_at(text, index) == 0x002C { "." } else { "," })
      run_start = index + 1
    }
    index += 1
  }
  copy_range(out, text, run_start, text.length())
  Some(out.to_string())
}

///|
/// 换成阿拉伯-印度数字：`1234` → `١٢٣٤`。
fn swap_digit_system(text : String) -> String? {
  let digits = arabic_digit_strings()
  let out = StringBuilder()
  let mut run_start = 0
  let mut changed = false
  let mut index = 0
  while index < text.length() {
    let unit = unit_at(text, index)
    if is_ascii_digit(unit) {
      copy_range(out, text, run_start, index)
      out.write_string(digits[unit - 0x0030])
      run_start = index + 1
      changed = true
    }
    index += 1
  }
  copy_range(out, text, run_start, text.length())
  if changed {
    Some(out.to_string())
  } else {
    None
  }
}

///|
/// 删掉双向控制符。
fn drop_bidi_marks(text : String) -> String? {
  let skip : Array[Int32] = []
  let mut index = 0
  while index < text.length() {
    if is_bidi_control(unit_at(text, index)) {
      skip.push(index)
    }
    index += 1
  }
  if skip.length() == 0 {
    None
  } else {
    Some(drop_at(text, skip))
  }
}

///|
fn has_any_digit(text : String) -> Bool {
  let mut index = 0
  while index < text.length() {
    if digit_value(unit_at(text, index)) is Some(_) {
      return true
    }
    index += 1
  }
  false
}

///|
/// 词形变化：末尾是字母就加 `s`（模拟复数类别选错）。
///
/// 只对**含数字**的期望值适用：复数类别是"数字 + 词形"共同决定的，
/// 纯文本串上做这个注入不构成复数问题。
fn pluralize_word(text : String) -> String? {
  if !has_any_digit(text) ||
    text.length() == 0 ||
    !is_ascii_letter(unit_at(text, text.length() - 1)) {
    return None
  }
  Some(text + "s")
}

///|
/// 紧凑缩写写错：数字**之后**的第一个字母后插入 `x`（模拟缩写表不对）。
///
/// 只改数字之后的字母：紧凑缩写在数字后面（`1.2K`、`1,2 Millionen`），
/// 而 `0E0` 这类科学计数法的 `E` 夹在数字中间，不属于紧凑形式，故不注入。
fn change_compact_form(text : String) -> String? {
  let mut last_digit = -1
  let mut index = 0
  while index < text.length() {
    if digit_value(unit_at(text, index)) is Some(_) {
      last_digit = index
    }
    index += 1
  }
  if last_digit < 0 {
    return None
  }
  let mut cursor = last_digit + 1
  while cursor < text.length() {
    if is_ascii_letter(unit_at(text, cursor)) {
      let out = StringBuilder()
      copy_range(out, text, 0, cursor + 1)
      out.write_string("x")
      copy_range(out, text, cursor + 1, text.length())
      return Some(out.to_string())
    }
    cursor += 1
  }
  None
}

///|
/// 按指定种类注入错误；该种类对这条期望值**不适用**时返回 `None`
/// （例如期望值里本来就没有分组分隔符，就无从"删掉分组"）。
pub fn mutate(kind : MutationKind, expected : String) -> String? {
  match kind {
    DropGrouping => drop_grouping(expected)
    DropDecimalPoint => drop_decimal_point(expected)
    SwapGroupingGlyph => swap_grouping_glyph(expected)
    SwapDigitSystem => swap_digit_system(expected)
    DropBidiMarks => drop_bidi_marks(expected)
    PluralizeWord => pluralize_word(expected)
    ChangeCompactForm => change_compact_form(expected)
    ReturnPattern =>
      if expected.length() == 0 {
        None
      } else {
        Some("#,##0.###")
      }
  }
}

///|
/// 一种注入在整批期望值上的成绩。
pub(all) struct MutationOutcome {
  kind : MutationKind
  intended : @conformance.FailReason
  /// 该注入在当前语料上可应用的条数。
  applied : Int32
  /// 归因还原出预定原因的条数。
  matched : Int32
  /// 实际归因分布（含未命中的去向，用于看误判方向）。
  attributed : Array[@conformance.ReasonCount]
  /// 一个具体样例 `期望 → 实际`，用于文档与人工复核。
  sample : String?
} derive(Debug, Eq)

///|
pub fn MutationOutcome::accuracy(self : MutationOutcome) -> Double {
  if self.applied == 0 {
    return 0.0
  }
  self.matched.to_double() / self.applied.to_double()
}

///|
pub fn MutationOutcome::accuracy_text(self : MutationOutcome) -> String {
  "\{(self.accuracy() * 100.0).to_int()}%"
}

///|
/// 对一批**期望值**逐一注入每种错误，统计归因还原率。
///
/// 这是归因的对照实验：正确答案由构造决定，因此这个矩阵是**可证伪**的——
/// 任何一条规则写错，都会在这里表现为还原率下降或误判方向改变。
pub fn mutation_matrix(
  expected_values : Array[String],
) -> Array[MutationOutcome] {
  let outcomes : Array[MutationOutcome] = []
  for kind in MutationKind::all() {
    let context = kind.context()
    let intended = kind.intended_reason()
    let observed : Array[@conformance.FailReason] = []
    let mut applied = 0
    let mut matched = 0
    let mut sample : String? = None
    for expected in expected_values {
      match mutate(kind, expected) {
        None => ()
        Some(actual) =>
          if actual != expected {
            applied += 1
            let reason = attribute(context, expected, actual)
            if reason == intended {
              matched += 1
            }
            observed.push(reason)
            if sample is None {
              sample = Some("\{expected} → \{actual}")
            }
          }
      }
    }
    let attributed : Array[@conformance.ReasonCount] = []
    for reason in @conformance.FailReason::all() {
      let mut count = 0
      for item in observed {
        if item == reason {
          count += 1
        }
      }
      if count > 0 {
        attributed.push({ reason, count, })
      }
    }
    outcomes.push({ kind, intended, applied, matched, attributed, sample, })
  }
  outcomes
}

///|
/// 把两种注入依次作用在同一条期望值上（模拟真实实现"同时错好几处"）。
/// 任一步不适用就返回 `None`。
fn apply_pair(
  first : MutationKind,
  second : MutationKind,
  expected : String,
) -> String? {
  match mutate(first, expected) {
    None => None
    Some(once) =>
      match mutate(second, once) {
        None => None
        Some(twice) => if twice == expected { None } else { Some(twice) }
      }
  }
}

///|
/// 复合注入下应采用的归因上下文。
///
/// 两处错误可能分别属于不同套件（例如"改复数词形" + "丢分组符"），
/// 这里取并集：出现复数注入按 MF2 语境，出现紧凑注入按紧凑语境。
fn compound_context(
  first : MutationKind,
  second : MutationKind,
) -> AttributionContext {
  if first == PluralizeWord || second == PluralizeWord {
    AttributionContext::new(@conformance.Suite::MessageFormat2)
  } else if first == ChangeCompactForm || second == ChangeCompactForm {
    AttributionContext::new(@conformance.Suite::Decimal, compact=true)
  } else {
    AttributionContext::new(@conformance.Suite::Decimal)
  }
}

///|
/// 两处同时出错时的成绩。
pub(all) struct CompoundOutcome {
  first : MutationKind
  second : MutationKind
  applied : Int32
  /// 归因命中"这两处之一"的条数（复合失败的合理判定）。
  hit_either : Int32
  /// 落到 `other` 的条数（保守兜底）。
  hit_other : Int32
  /// 落到与两者都无关的类别的条数（**真正需要关注的误判**）。
  hit_unrelated : Int32
  attributed : Array[@conformance.ReasonCount]
  sample : String?
} derive(Debug, Eq)

///|
pub fn CompoundOutcome::hit_rate(self : CompoundOutcome) -> Double {
  if self.applied == 0 {
    return 0.0
  }
  self.hit_either.to_double() / self.applied.to_double()
}

///|
pub fn CompoundOutcome::hit_rate_text(self : CompoundOutcome) -> String {
  "\{(self.hit_rate() * 100.0).to_int()}%"
}

///|
fn compound_outcome(
  first : MutationKind,
  second : MutationKind,
  expected_values : Array[String],
) -> CompoundOutcome {
  let context = compound_context(first, second)
  let observed : Array[@conformance.FailReason] = []
  let mut applied = 0
  let mut hit_either = 0
  let mut hit_other = 0
  let mut hit_unrelated = 0
  let mut sample : String? = None
  for expected in expected_values {
    match apply_pair(first, second, expected) {
      None => ()
      Some(actual) =>
        if actual != expected {
          applied += 1
          // 复合场景用**完整原因集**判断：命中两者之一即算还原。
          let reasons = attribute_all(context, expected, actual)
          let is_first = reasons.contains(first.intended_reason())
          let is_second = reasons.contains(second.intended_reason())
          if is_first || is_second {
            hit_either += 1
          } else if reasons[0] == @conformance.FailReason::Other {
            hit_other += 1
          } else {
            hit_unrelated += 1
          }
          observed.push(reasons[0])
          if sample is None {
            sample = Some("\{expected} → \{actual}")
          }
        }
    }
  }
  let attributed : Array[@conformance.ReasonCount] = []
  for reason in @conformance.FailReason::all() {
    let mut count = 0
    for item in observed {
      if item == reason {
        count += 1
      }
    }
    if count > 0 {
      attributed.push({ reason, count, })
    }
  }
  {
    first,
    second,
    applied,
    hit_either,
    hit_other,
    hit_unrelated,
    attributed,
    sample,
  }
}

///|
/// 全部两两组合的复合注入实验（只测 i < j，避免重复）。
pub fn compound_matrix(
  expected_values : Array[String],
) -> Array[CompoundOutcome] {
  let kinds = MutationKind::all()
  let outcomes : Array[CompoundOutcome] = []
  let mut i = 0
  while i < kinds.length() {
    let mut j = i + 1
    while j < kinds.length() {
      outcomes.push(compound_outcome(kinds[i], kinds[j], expected_values))
      j += 1
    }
    i += 1
  }
  outcomes
}

///|
/// 渲染复合注入实验：逐对给出"命中两者之一 / 落到 other / 落到无关类别"。
pub fn render_compound_matrix(outcomes : Array[CompoundOutcome]) -> String {
  let out = StringBuilder()
  out.write_string(
    "| 复合注入（同时错两处） | 可应用 | 命中其一 | 命中率 | 落到 other | 落到无关类别 |\n",
  )
  out.write_string("|---|---|---|---|---|---|\n")
  let mut applied_total = 0
  let mut hit_total = 0
  let mut other_total = 0
  let mut unrelated_total = 0
  for outcome in outcomes {
    applied_total += outcome.applied
    hit_total += outcome.hit_either
    other_total += outcome.hit_other
    unrelated_total += outcome.hit_unrelated
    out.write_string(
      "| `\{outcome.first.label()}` + `\{outcome.second.label()}` | \{outcome.applied} | \{outcome.hit_either} | \{outcome.hit_rate_text()} | \{outcome.hit_other} | \{outcome.hit_unrelated} |\n",
    )
  }
  let rate = if applied_total == 0 {
    "0%"
  } else {
    "\{((hit_total.to_double() / applied_total.to_double()) * 100.0).to_int()}%"
  }
  out.write_string(
    "\n合计：\{hit_total}/\{applied_total} 命中其一（**\{rate}**）；落到 `other` \{other_total}；落到无关类别 \{unrelated_total}。\n",
  )
  out.to_string()
}

///|
/// 把对照实验结果渲染成 Markdown（可直接贴进说明文档）。
pub fn render_mutation_matrix(outcomes : Array[MutationOutcome]) -> String {
  let out = StringBuilder()
  out.write_string(
    "| 注入（只破坏一个维度） | 预定原因 | 可应用 | 还原 | 还原率 | 误判去向 |\n",
  )
  out.write_string("|---|---|---|---|---|---|\n")
  let mut applied_total = 0
  let mut matched_total = 0
  for outcome in outcomes {
    applied_total += outcome.applied
    matched_total += outcome.matched
    let mut misses = ""
    for entry in outcome.attributed {
      if entry.reason != outcome.intended {
        if misses != "" {
          misses = misses + "、"
        }
        misses = misses + "\{entry.reason.label()}×\{entry.count}"
      }
    }
    out.write_string(
      "| `\{outcome.kind.label()}` | \{outcome.intended.label()} | \{outcome.applied} | \{outcome.matched} | \{outcome.accuracy_text()} | \{if misses == "" { "—" } else { misses }} |\n",
    )
  }
  let rate = if applied_total == 0 {
    "0%"
  } else {
    "\{((matched_total.to_double() / applied_total.to_double()) * 100.0).to_int()}%"
  }
  out.write_string(
    "\n合计：\{matched_total}/\{applied_total} 条还原，总体还原率 **\{rate}**。\n",
  )
  out.write_string(
    "\n### 逐类样例（真实 CLDR 期望值 → 注入后的输出）\n\n",
  )
  for outcome in outcomes {
    match outcome.sample {
      Some(sample) =>
        out.write_string(
          "- `\{outcome.kind.label()}`：`\{sample}` ⇒ 归因 **\{outcome.intended.label()}**（预定）\n",
        )
      None => ()
    }
  }
  out.to_string()
}
