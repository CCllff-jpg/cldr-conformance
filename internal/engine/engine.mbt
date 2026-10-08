///|
/// 执行引擎配置。
///
/// `full` 为真时启用扩展数据档（`decimals_extended_numbers.tsv`、
/// `skeletons_random_5percent.tsv`），否则只跑快速档（见 开发方案.md §3.1）。
pub(all) struct EngineConfig {
  full : Bool
} derive(Debug, Eq)

///|
pub fn EngineConfig::default() -> EngineConfig {
  { full: false, }
}
