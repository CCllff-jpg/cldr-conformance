///|
/// 语料库规模统计。
///
/// 用途：报告头部展示，以及**数据自检**——防止解析静默丢行导致一致率虚高
/// （见 开发方案.md §5 测试策略与 §3.1 数据策略）。
pub(all) struct CorpusStats {
  cases : Int
  locales : Int
} derive(Debug, Eq)

///|
pub fn CorpusStats::empty() -> CorpusStats {
  { cases: 0, locales: 0, }
}

///|
pub fn CorpusStats::is_empty(self : CorpusStats) -> Bool {
  self.cases == 0
}
