///|
/// 适配器登记信息。
///
/// `installed` 为假时该实现整体记为 `CaseOutcome::NotInstalled`，
/// 而不是把它的每条用例都判成失败（见 DESIGN.md D3）。
pub(all) struct AdapterInfo {
  name : String
  installed : Bool
} derive(Debug, Eq)

///|
pub fn AdapterInfo::new(
  name~ : String,
  installed? : Bool = true,
) -> AdapterInfo {
  { name, installed, }
}
