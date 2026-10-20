///|
/// 解析 CLDR `supplemental/plurals.xml` 的**样本值**，生成复数类别用例。
///
/// 该文件为每个复数类别列出了示例值（`@integer 0, 1` / `@integer 2~17, 100`），
/// 这就是权威的期望类别。因此本项目**不需要实现复数规则求值**——
/// 守住了"不实现格式化算法"的 Non-goal（见 `DESIGN.md`）。
///
/// 只取 `@integer` 段：整数样本足以覆盖类别选择，且与被测库普遍只接受整数的 API 对齐。
pub fn plural_corpus_from_xml(
  text : StringView,
  source : String,
) -> @conformance.PluralCorpus {
  let xml = text.to_owned()
  let cases : Array[@conformance.PluralCase] = []
  let mut locales : Array[String] = []
  let mut index = 0
  while index < xml.length() {
    let lt = match find_from(xml, "<", index) {
      Some(found) => found
      None => break
    }
    if starts_with_at(xml, lt, "<pluralRules locales=\"") {
      let start = lt + "<pluralRules locales=\"".length()
      let stop = match find_from(xml, "\"", start) {
        Some(found) => found
        None => break
      }
      locales = split_tokens(slice(xml, start, stop), 0x0020)
      index = stop
    } else if starts_with_at(xml, lt, "<pluralRule count=\"") {
      let start = lt + "<pluralRule count=\"".length()
      let stop = match find_from(xml, "\"", start) {
        Some(found) => found
        None => break
      }
      let category = slice(xml, start, stop)
      let body_start = match find_from(xml, "@integer", stop) {
        Some(found) => found
        None => break
      }
      let body_from = body_start + "@integer".length()
      let body_end = match
        find_first_from(xml, ["@decimal", "</pluralRule>"], body_from) {
        Some(found) => found
        None => break
      }
      let samples = expand_samples(slice(xml, body_from, body_end), 40)
      for locale in locales {
        for value in samples {
          cases.push({
            locale,
            input: value.to_string(),
            expected: category,
            source,
            // XML 没有行号概念，这里用序号保证每条用例的位置唯一可指
            line: cases.length() + 1,
          })
        }
      }
      index = body_end
    } else {
      index = lt + 1
    }
  }
  @conformance.PluralCorpus::new(cases)
}

///|
/// 展开样本段，例如 ` 0~15, 100, …` → `[0, 1, …, 15, 100]`。
///
/// `cap` 限制单条规则的展开数量，避免异常大的范围把语料撑爆。
fn expand_samples(segment : String, cap : Int32) -> Array[Int32] {
  let values : Array[Int32] = []
  for token in split_tokens(segment, 0x002C) {
    if values.length() >= cap {
      break
    }
    let trimmed = trim(token)
    if trimmed == "" || trimmed == "…" || trimmed == "..." {
      continue
    }
    match parse_range(trimmed) {
      Some((low, high)) => {
        let mut value = low
        while value <= high && values.length() < cap {
          values.push(value)
          value += 1
        }
      }
      None => ()
    }
  }
  values
}

///|
/// 解析 `N` 或 `A~B`；带小数点、负数或畸形写法一律跳过（只取整数样本）。
fn parse_range(text : String) -> (Int32, Int32)? {
  let tilde = find_from(text, "~", 0)
  match tilde {
    Some(position) => {
      let low = parse_uint(slice(text, 0, position))
      let high = parse_uint(slice(text, position + 1, text.length()))
      match (low, high) {
        (Some(low), Some(high)) =>
          if low <= high {
            Some((low, high))
          } else {
            None
          }
        _ => None
      }
    }
    None =>
      match parse_uint(text) {
        Some(value) => Some((value, value))
        None => None
      }
  }
}

///|
fn parse_uint(text : String) -> Int32? {
  let trimmed = trim(text)
  if trimmed.length() == 0 {
    return None
  }
  let mut index = 0
  let mut value = 0
  while index < trimmed.length() {
    let unit = trimmed[index].to_int()
    if unit < 0x0030 || unit > 0x0039 {
      return None
    }
    value = value * 10 + (unit - 0x0030)
    index += 1
  }
  Some(value)
}

///|
fn trim(text : String) -> String {
  let mut start = 0
  let mut stop = text.length()
  while start < stop && is_space_unit(text[start].to_int()) {
    start += 1
  }
  while stop > start && is_space_unit(text[stop - 1].to_int()) {
    stop -= 1
  }
  slice(text, start, stop)
}

///|
fn is_space_unit(unit : Int32) -> Bool {
  unit == 0x0020 || unit == 0x000A || unit == 0x000D || unit == 0x0009
}

///|
fn split_tokens(text : String, separator : Int32) -> Array[String] {
  let out : Array[String] = []
  let mut start = 0
  let mut index = 0
  while index < text.length() {
    if text[index].to_int() == separator {
      out.push(slice(text, start, index))
      start = index + 1
    }
    index += 1
  }
  out.push(slice(text, start, text.length()))
  out
}

///|
fn find_from(text : String, needle : String, from : Int32) -> Int32? {
  let mut index = from
  while index + needle.length() <= text.length() {
    if slice(text, index, index + needle.length()) == needle {
      return Some(index)
    }
    index += 1
  }
  None
}

///|
/// 在若干候选里找最早出现的一个。
fn find_first_from(
  text : String,
  needles : Array[String],
  from : Int32,
) -> Int32? {
  let mut best : Int32? = None
  for needle in needles {
    match find_from(text, needle, from) {
      Some(found) =>
        match best {
          Some(current) => if found < current { best = Some(found) }
          None => best = Some(found)
        }
      None => ()
    }
  }
  best
}

///|
fn starts_with_at(text : String, index : Int32, prefix : String) -> Bool {
  index + prefix.length() <= text.length() &&
  slice(text, index, index + prefix.length()) == prefix
}

///|
fn slice(text : String, start : Int32, end : Int32) -> String {
  text.clamped_view(start~, end~).to_owned()
}
