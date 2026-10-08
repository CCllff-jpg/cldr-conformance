///|
/// 恒返回输入值的空实现。
///
/// 用途：让执行引擎在还没有接入任何真实适配器时也能端到端跑通，
/// 且结果是**可预测的**（除恰好相同的输入外必然 fail），
/// 从而可以自测引擎与归因逻辑本身（见 开发方案.md §4.0 D5、§5 测试策略）。
///
/// 注意：它不是"参考实现"，不实现任何格式化逻辑，只用于测试引擎。
pub(all) struct ReferenceNull {
  label : String
} derive(Debug, Eq)

///|
pub fn ReferenceNull::new() -> ReferenceNull {
  { label: "reference-null", }
}

///|
pub impl @conformance.FormatUnderTest for ReferenceNull with fn name(self) {
  self.label
}

///|
pub impl @conformance.FormatUnderTest for ReferenceNull with fn format_number(
  self,
  locale,
  value,
  style~,
  length~,
) {
  ignore(self)
  ignore(locale)
  ignore(style)
  ignore(length)
  value
}
