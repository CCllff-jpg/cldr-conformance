///|
/// 主 CLI：清点数据 → 跑套件 → 输出报告。
///
/// 当前（D4）做到「清点」：把 fixtures 里的官方数据解析成用例并打印规模。
/// 执行与报告在 D6–D7 接入：
///   moon run cmd/conform -- --suite decimal --format markdown
async fn main {
  let args = @env.args()
  let registry = @adapter.AdapterRegistry::new()
  let reference_null = @reference_null.ReferenceNull::new()
  registry.register(
    @adapter.AdapterInfo::new(
      id="reference_null",
      name="reference-null",
      capabilities=@conformance.AdapterCapabilities::all(),
    ),
    number=Some(reference_null as &@conformance.NumberAdapter),
    datetime=Some(reference_null as &@conformance.DatetimeAdapter),
    message_format_2=Some(reference_null as &@conformance.MessageFormat2Adapter),
  )
  let selected = select_adapters(registry, args)

  let manifest = @source.load_manifest("fixtures/SOURCES.json")
  println("cldr-conformance · conform")
  println("已选择适配器（M1 登记）：\{selected.length()}")
  for info in selected {
    println(
      "  \{info.id} · \{info.name} · \{capability_labels(info.capabilities)}",
    )
  }
  println(
    "数据基线 \{manifest.cldr_version}（\{manifest.files.length()} 个文件）",
  )
  let decimal = @corpus.decimal_corpus_from_tsv(
    @fs.read_file("fixtures/decimal/decimals.tsv").text(),
  )
  println(
    "  数字套件  decimals.tsv                \{decimal.length()} 条用例 / \{decimal.locales().length()} 个语言",
  )
  let modern = @corpus.decimal_corpus_from_tsv(
    @fs.read_file("fixtures/decimal/decimals_modern_locales.tsv").text(),
  )
  println(
    "  数字套件  decimals_modern_locales.tsv \{modern.length()} 条用例 / \{modern.locales().length()} 个语言",
  )
  let datetime = @corpus.datetime_corpus_from_text(
    @fs.read_file("fixtures/datetime/skeletons.tsv").text(),
    @fs.read_file("fixtures/datetime/skeletons_all_calendars.tsv").text(),
    @fs.read_file("fixtures/datetime/datetime.json").text(),
  )
  println(
    "  日期套件  \{datetime.skeletons.length()} 条骨架 + \{datetime.formatted.length()} 条格式化 / \{datetime.locales().length()} 个语言 / \{datetime.calendars().length()} 种日历",
  )
  // MF2：7 个文件各自带场景与默认值，逐个解析后合并
  let tests_dir = "fixtures/messageFormat/tests"
  let names = [
    "syntax", "syntax-errors", "data-model-errors", "pattern-selection", "fallback",
    "bidi", "u-options",
  ]
  let mut message_cases : Array[@conformance.MessageCase] = []
  for name in names {
    let file = "\{name}.json"
    message_cases = message_cases +
      @corpus.parse_message_tests(
        file,
        @fs.read_file("\{tests_dir}/\{file}").text(),
      )
  }
  let messages = @conformance.MessageCorpus::new(message_cases)
  println(
    "  MF2 套件  \{messages.length()} 条用例 / \{messages.files().length()} 个文件 / \{messages.scenarios().length()} 个场景",
  )
  println(
    "  待实现：适配器执行、失败归因与报告输出（D6–D7）",
  )
}

///|
fn select_adapters(
  registry : @adapter.AdapterRegistry,
  args : Array[String],
) -> Array[@adapter.AdapterInfo] raise @adapter.AdapterRegistryError {
  match flag_value(args, "--impls") {
    Some(value) => registry.select(parse_ids(value))
    None => registry.installed()
  }
}

///|
fn flag_value(args : Array[String], flag : String) -> String? {
  let mut index = 0
  while index < args.length() {
    if args[index] == flag {
      return Some(if index + 1 < args.length() { args[index + 1] } else { "" })
    }
    index += 1
  }
  None
}

///|
fn parse_ids(value : String) -> Array[String] {
  let ids : Array[String] = []
  for id in value.split(",") {
    ids.push(id.to_owned())
  }
  ids
}

///|
fn capability_labels(capabilities : @conformance.AdapterCapabilities) -> String {
  let mut result = ""
  for capability in @conformance.AdapterCapability::all() {
    if capabilities.contains(capability) {
      if result != "" {
        result = result + ", "
      }
      result = result + capability.label()
    }
  }
  result
}
