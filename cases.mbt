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
/// 涉及的语言，去重后按字典序排列（报告表头需要稳定顺序）。
pub fn DecimalCorpus::locales(self : DecimalCorpus) -> Array[String] {
  let seen : Map[String, Unit] = Map([])
  for item in self.cases {
    seen[item.locale] = ()
  }
  let locales = seen.keys().to_array()
  locales.sort()
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
