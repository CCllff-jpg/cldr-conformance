///|
/// `Zhouz-z/moon_l10n@0.2.0` 的复数类别适配器。
///
/// 该库实现的是 **ICU MessageFormat**，与 MF2 属不同标准，因此不参与 MF2 套件；
/// 但它的 `plural_category(String, Int)` 与 CLDR 的复数类别直接对应，
/// 所以**复数类别选择**是它唯一可直接可比的维度（见 `可比性映射.md`）。
pub(all) struct MoonL10nPluralAdapter {
  label : String
} derive(Debug, Eq)

///|
pub fn MoonL10nPluralAdapter::new() -> MoonL10nPluralAdapter {
  { label: "moon_l10n", }
}

///|
pub(all) suberror MoonL10nPluralAdapterError {
  /// 用例数值不是整数（当前语料只取整数样本）
  BadValue(value~ : String)
} derive(Debug)

///|
/// 十进制整数字符串 → Int。失败返回 `None`。
pub fn parse_count(text : String) -> Int32? {
  if text.length() == 0 {
    return None
  }
  let mut index = 0
  let mut negative = false
  if text[0].to_int() == 0x002D {
    negative = true
    index = 1
  }
  let mut value = 0
  let mut digits = 0
  while index < text.length() {
    let unit = text[index].to_int()
    if unit < 0x0030 || unit > 0x0039 {
      return None
    }
    value = value * 10 + (unit - 0x0030)
    digits += 1
    index += 1
  }
  if digits == 0 {
    return None
  }
  Some(if negative { -value } else { value })
}

///|
pub impl @conformance.PluralAdapter for MoonL10nPluralAdapter with fn name(self) {
  self.label
}

///|
pub impl @conformance.PluralAdapter for MoonL10nPluralAdapter with fn plural_category(
  self,
  locale,
  value,
) {
  ignore(self)
  match parse_count(value) {
    Some(count) => @upstream.plural_category(locale, count)
    None => raise MoonL10nPluralAdapterError::BadValue(value~)
  }
}
