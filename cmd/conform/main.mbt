///|
/// 主 CLI：清点数据 → 执行套件 → 输出计数汇总。
///
/// 当前（M2）已能真正跑完 4714 条用例并给出分类计数；
/// 失败归因与报告模型（JSON / Markdown）在 M3 接入：
///   moon run cmd/conform -- --impls moonlocale --format markdown
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
  let selected_ids = selected.map(info => info.id)

  let manifest = @source.load_manifest("fixtures/SOURCES.json")
  println("cldr-conformance · conform")
  println("已选择适配器：\{selected.length()}")
  for info in selected {
    println(
      "  \{info.id} · \{info.name} · \{capability_labels(info.capabilities)}",
    )
  }
  println(
    "数据基线 \{manifest.cldr_version}（\{manifest.files.length()} 个文件）",
  )

  // ---- 载入用例（同一份文本既用于清点，也用于执行）----
  let decimal_text = @fs.read_file("fixtures/decimal/decimals.tsv").text()
  let modern_text = @fs.read_file(
    "fixtures/decimal/decimals_modern_locales.tsv",
  ).text()
  let skeletons_text = @fs.read_file("fixtures/datetime/skeletons.tsv").text()
  let all_calendars_text = @fs.read_file(
    "fixtures/datetime/skeletons_all_calendars.tsv",
  ).text()
  let datetime_text = @fs.read_file("fixtures/datetime/datetime.json").text()

  let decimal = @corpus.decimal_corpus_from_tsv(decimal_text)
  let modern = @corpus.decimal_corpus_from_tsv(modern_text)
  let skeletons = @corpus.parse_skeleton_cases(
    @corpus.parse_tsv(skeletons_text),
  )
  let all_calendars = @corpus.parse_skeleton_cases(
    @corpus.parse_tsv(all_calendars_text),
  )
  let formatted = @corpus.parse_datetime_json(datetime_text)
  let datetime = @conformance.DatetimeCorpus::new(
    skeletons + all_calendars,
    formatted,
  )
  println(
    "  数字套件  decimals.tsv                \{decimal.length()} 条用例 / \{decimal.locales().length()} 个语言",
  )
  println(
    "  数字套件  decimals_modern_locales.tsv \{modern.length()} 条用例 / \{modern.locales().length()} 个语言",
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

  // ---- 执行（M2 引擎）----
  if selected.length() == 0 {
    println("没有可执行的适配器；用 --impls <id,...> 指定。")
    return
  }
  let config = @engine.EngineConfig::default()
  let mut results : Array[@conformance.CaseResult] = []
  results = results +
    @engine.run_number(
      registry,
      selected_ids,
      "decimals.tsv",
      decimal.cases,
      config,
    )
  results = results +
    @engine.run_number(
      registry,
      selected_ids,
      "decimals_modern_locales.tsv",
      modern.cases,
      config,
    )
  results = results +
    @engine.run_skeleton(
      registry, selected_ids, "skeletons.tsv", skeletons, config,
    )
  results = results +
    @engine.run_skeleton(
      registry, selected_ids, "skeletons_all_calendars.tsv", all_calendars, config,
    )
  results = results +
    @engine.run_datetime(
      registry, selected_ids, "datetime.json", formatted, config,
    )
  results = results +
    @engine.run_message(registry, selected_ids, message_cases, config)

  println(
    "执行结果（\{results.length()} 条结果 = 用例 × 适配器）",
  )
  for info in selected {
    let summary = @conformance.RunSummary::from_results(
      results.filter(result => result.adapter_id == info.id),
    )
    println("  \{info.id}: \{summary.render()}")
  }
  println(
    "  合计: \{@conformance.RunSummary::from_results(results).render()}",
  )
  let failures = results.filter(result => result.outcome.is_failure())
  let mut shown = 0
  for result in failures {
    if shown < 3 {
      let label = match result.outcome.reason_label() {
        Some(reason) => "\{result.outcome.label()} · \{reason}"
        None => result.outcome.label()
      }
      println("    例: \{result.source} \{result.location} · \{label}")
      shown += 1
    }
  }
  println("  报告输出（JSON / Markdown）：M3 下一步接入")
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
