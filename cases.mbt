///|
/// 一条数字格式化用例：`decimals*.tsv` 的一行。
///
/// `input` 与 `expected` 都按**字符串原样**保存：CLDR 给的输入本身就是十进制字符串，
/// 转成浮点会引入舍入误差，恰好污染本项目要度量的那个维度（见 DESIGN.md D2）。
pub(all) struct DecimalCase {
  locale : String
  style : NumberStyle
  length : NumberLength
  input : String
  expected : String
  /// 源文件行号（1 起，含表头行），用于报告定位。
  line : Int
} derive(Debug, Eq)

///|
/// 数字套件的用例集合。
pub(all) struct DecimalCorpus {
  cases : Array[DecimalCase]
} derive(Debug, Eq)

///|
pub fn DecimalCorpus::new(cases : Array[DecimalCase]) -> DecimalCorpus {
  { cases, }
}

///|
pub fn DecimalCorpus::length(self : DecimalCorpus) -> Int {
  self.cases.length()
}

///|
/// 字典序比较：逐码元比较；一个是另一个的前缀时，短的排前面。
///
/// **不能直接用 `Array::sort()`**：MoonBit 的 `Compare for String` 是「先比长度、
/// 再逐码元」（见 core `builtin/string.mbt`），于是 `"en"` 会排在 `"ar-SA"` 前面。
/// 报告表格要给人看，所以这里显式给出符合直觉的顺序。
fn lexicographic_compare(a : String, b : String) -> Int {
  let limit = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<limit {
    let left = a[i]
    let right = b[i]
    if left != right {
      return if left < right { -1 } else { 1 }
    }
  }
  if a.length() == b.length() {
    0
  } else if a.length() < b.length() {
    -1
  } else {
    1
  }
}

///|
/// 涉及的语言，去重后按字典序排列（报告表头需要稳定顺序）。
pub fn DecimalCorpus::locales(self : DecimalCorpus) -> Array[String] {
  let seen : Map[String, Unit] = Map([])
  for item in self.cases {
    seen[item.locale] = ()
  }
  let locales = seen.keys().to_array()
  locales.sort_by(lexicographic_compare)
  locales
}

///|
/// 某个语言的用例（保持源文件顺序）。
pub fn DecimalCorpus::of_locale(
  self : DecimalCorpus,
  locale : String,
) -> Array[DecimalCase] {
  self.cases.filter(item => item.locale == locale)
}

///|
/// 一条「骨架 → 模式」用例：`skeletons*.tsv` 的一行。
pub(all) struct SkeletonCase {
  locale : String
  calendar : String
  skeleton : String
  pattern : String
  /// 源文件行号（1 起，含表头行）。
  line : Int
} derive(Debug, Eq)

///|
/// 一条「时间输入 → 格式化输出」用例：`datetime.json` 的一个元素。
///
/// 可选字段按上游原样保留（缺省即该项未被测试），刻意不做归一化：
/// 报告要能说明「这条用例到底在测哪个能力」。
pub(all) struct DatetimeCase {
  locale : String
  calendar : String
  /// ISO 8601 时间串，含 IANA 时区标注，例如 `2000-01-01T00:00Z[Etc/GMT]`。
  input : String
  expected : String
  semantic_skeleton : String?
  classical_skeleton : String?
  semantic_skeleton_length : String?
  zone_style : String?
  time_length : String?
  date_length : String?
  hour_cycle : String?
  year_style : String?
  date_time_format_type : String?
  /// 在源文件数组中的下标（0 起），用于报告定位。
  index : Int
} derive(Debug, Eq)

///|
/// 日期套件的用例集合：骨架表 + 格式化用例。
pub(all) struct DatetimeCorpus {
  skeletons : Array[SkeletonCase]
  formatted : Array[DatetimeCase]
} derive(Debug, Eq)

///|
pub fn DatetimeCorpus::new(
  skeletons : Array[SkeletonCase],
  formatted : Array[DatetimeCase],
) -> DatetimeCorpus {
  { skeletons, formatted, }
}

///|
pub fn DatetimeCorpus::length(self : DatetimeCorpus) -> Int {
  self.skeletons.length() + self.formatted.length()
}

///|
/// 涉及的语言（两个来源合并、去重后按字典序）。
pub fn DatetimeCorpus::locales(self : DatetimeCorpus) -> Array[String] {
  let seen : Map[String, Unit] = Map([])
  for item in self.skeletons {
    seen[item.locale] = ()
  }
  for item in self.formatted {
    seen[item.locale] = ()
  }
  let locales = seen.keys().to_array()
  locales.sort_by(lexicographic_compare)
  locales
}

///|
/// 涉及的日历（两个来源合并、去重后按字典序）。
pub fn DatetimeCorpus::calendars(self : DatetimeCorpus) -> Array[String] {
  let seen : Map[String, Unit] = Map([])
  for item in self.skeletons {
    seen[item.calendar] = ()
  }
  for item in self.formatted {
    seen[item.calendar] = ()
  }
  let calendars = seen.keys().to_array()
  calendars.sort_by(lexicographic_compare)
  calendars
}

///|
/// 一条 MF2 用例（`messageFormat/tests/*.json` 的一个 test）。
///
/// 上游用「**文件级默认值 + 用例级覆盖**」表达期望：例如 `syntax-errors.json` 的
/// `defaultTestProperties` 带 `expErrors`，其 133 个用例只写 `src` 就继承了它。
/// 因此这里存的是**合并后**的结果，而不是用例的原始字段。
pub(all) struct MessageCase {
  /// 来源文件名，例如 `syntax.json`。
  file : String
  scenario : String
  /// 在该文件 `tests` 数组中的下标（0 起）。
  index : Int
  description : String?
  /// MF2 消息源码。
  src : String
  /// 合并默认值后的语言。
  locale : String
  /// 合并默认值后的 bidi 隔离设置（`None` 表示上游未指定）。
  bidi_isolation : String?
  /// 期望输出；`None` 表示该用例期望失败（见 `expected_errors`）。
  exp : String?
  /// 期望的错误类别，例如 `syntax-error`、`bad-option`。
  expected_errors : Array[String]
  /// 该用例期望结构化 parts 输出。当前实现普遍不产出，故单独标记而不是当作通过。
  expects_parts : Bool
  /// `u:` 选项标签（仅 u-options.json 使用）。
  tags : Array[String]
  /// 输入参数的原始 JSON 片段，交给适配器自行解析（避免在这里过度建模）。
  params_json : String?
} derive(Debug, Eq)

///|
/// MF2 套件的用例集合。
pub(all) struct MessageCorpus {
  cases : Array[MessageCase]
} derive(Debug, Eq)

///|
pub fn MessageCorpus::new(cases : Array[MessageCase]) -> MessageCorpus {
  { cases, }
}

///|
pub fn MessageCorpus::length(self : MessageCorpus) -> Int {
  self.cases.length()
}

///|
/// 涉及的来源文件（去重后按字典序）。
pub fn MessageCorpus::files(self : MessageCorpus) -> Array[String] {
  let seen : Map[String, Unit] = Map([])
  for item in self.cases {
    seen[item.file] = ()
  }
  let files = seen.keys().to_array()
  files.sort_by(lexicographic_compare)
  files
}

///|
/// 涉及的上游场景（去重后按字典序）。
pub fn MessageCorpus::scenarios(self : MessageCorpus) -> Array[String] {
  let seen : Map[String, Unit] = Map([])
  for item in self.cases {
    seen[item.scenario] = ()
  }
  let scenarios = seen.keys().to_array()
  scenarios.sort_by(lexicographic_compare)
  scenarios
}

///|
/// 某个场景的用例（保持源文件顺序）。
pub fn MessageCorpus::of_scenario(
  self : MessageCorpus,
  scenario : String,
) -> Array[MessageCase] {
  self.cases.filter(item => item.scenario == scenario)
}
