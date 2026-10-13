///|
test "按稳定 ID 登记和查找适配器" {
  let registry = AdapterRegistry::new()
  let info = AdapterInfo::new(
    id="test_adapter",
    name="测试实现",
    capabilities=@conformance.AdapterCapabilities::new([]),
  )
  registry.register(info)
  assert_true(registry.find("test_adapter") is Some(_))
  assert_true(registry.find("missing") is None)
}

///|
test "默认选择已安装适配器，显式选择保留未安装项" {
  let registry = AdapterRegistry::new()
  registry.register(
    AdapterInfo::new(
      id="available",
      name="已安装",
      capabilities=@conformance.AdapterCapabilities::new([]),
    ),
  )
  registry.register(
    AdapterInfo::new(
      id="not_installed",
      name="未安装",
      capabilities=@conformance.AdapterCapabilities::new([]),
      installed=false,
    ),
  )
  assert_eq(registry.installed().map(info => info.id), ["available"])
  assert_eq(registry.select(["not_installed"]).map(info => info.id), [
    "not_installed",
  ])
}

///|
test "未选入或未安装归为 NotInstalled，未声明能力归为 Unsupported" {
  let registry = AdapterRegistry::new()
  registry.register(
    AdapterInfo::new(
      id="metadata_only",
      name="无格式化能力",
      capabilities=@conformance.AdapterCapabilities::new([]),
    ),
  )
  let unsupported = registry.unavailable_outcome(
    "metadata_only",
    ["metadata_only"],
    @conformance.AdapterCapability::Decimal,
  )
  assert_eq(
    unsupported,
    Some(@conformance.CaseOutcome::Unsupported(feature="decimal")),
  )
  let not_selected = registry.unavailable_outcome(
    "metadata_only",
    [],
    @conformance.AdapterCapability::Decimal,
  )
  assert_eq(not_selected, Some(@conformance.CaseOutcome::NotInstalled))
}

///|
test "选择未知稳定 ID 会报错" {
  let registry = AdapterRegistry::new()
  ignore(registry.select(["unknown"])) catch {
    AdapterRegistryError::UnknownId(id="unknown") => ()
    _ => fail("未知适配器应返回 UnknownId")
  }
}

///|
test "登记能力必须有对应公开 trait handler" {
  let registry = AdapterRegistry::new()
  try {
    registry.register(
      AdapterInfo::new(
        id="missing_handler",
        name="缺少 handler",
        capabilities=@conformance.AdapterCapabilities::new([
          @conformance.AdapterCapability::Decimal,
        ]),
      ),
    )
    fail("缺少 handler 应拒绝登记")
  } catch {
    AdapterRegistryError::MissingHandler(
      id="missing_handler",
      capability="decimal"
    ) => ()
    _ => fail("缺少 handler 应返回 MissingHandler")
  }
}

///|
test "重复稳定 ID 不得覆盖已有登记" {
  let registry = AdapterRegistry::new()
  let info = AdapterInfo::new(
    id="duplicate",
    name="重复项",
    capabilities=@conformance.AdapterCapabilities::new([]),
  )
  registry.register(info)
  registry.register(info) catch {
    AdapterRegistryError::DuplicateId(id="duplicate") => ()
    _ => fail("重复 ID 应返回 DuplicateId")
  }
}

///|
test "未安装状态默认开启，也可显式关闭" {
  let enabled = AdapterInfo::new(
    id="enabled",
    name="已安装",
    capabilities=@conformance.AdapterCapabilities::new([]),
  )
  let disabled = AdapterInfo::new(
    id="disabled",
    name="未安装",
    capabilities=@conformance.AdapterCapabilities::new([]),
    installed=false,
  )
  assert_true(enabled.installed)
  assert_false(disabled.installed)
}

///|
test "能力集合去重并按声明查询" {
  let capabilities = @conformance.AdapterCapabilities::new([
    @conformance.AdapterCapability::Decimal,
    @conformance.AdapterCapability::Decimal,
  ])
  assert_true(capabilities.contains(@conformance.AdapterCapability::Decimal))
  assert_false(
    capabilities.contains(@conformance.AdapterCapability::MessageFormat2),
  )
}

///|
test "登记表保存并分发三个 suite trait 对象" {
  let registry = AdapterRegistry::new()
  let implementation = @reference_null.ReferenceNull::new()
  registry.register(
    AdapterInfo::new(
      id="reference_null",
      name="reference-null",
      capabilities=@conformance.AdapterCapabilities::all(),
    ),
    number=Some(implementation as &@conformance.NumberAdapter),
    datetime=Some(implementation as &@conformance.DatetimeAdapter),
    message_format_2=Some(implementation as &@conformance.MessageFormat2Adapter),
  )

  match registry.number_adapter("reference_null") {
    Some(adapter) =>
      assert_eq(
        @conformance.NumberAdapter::format_number(
          adapter,
          "en",
          "42.5",
          style=@conformance.NumberStyle::DecimalStyle,
          length=@conformance.NumberLength::Standard,
        ),
        "42.5",
      )
    None => fail("数字 trait 未从登记表取出")
  }
  match registry.datetime_adapter("reference_null") {
    Some(adapter) =>
      assert_eq(
        @conformance.DatetimeAdapter::format_skeleton(
          adapter, "en", "gregory", "yMd",
        ),
        "yMd",
      )
    None => fail("日期 trait 未从登记表取出")
  }
  match registry.message_format_2_adapter("reference_null") {
    Some(adapter) =>
      assert_eq(
        @conformance.MessageFormat2Adapter::format_message(adapter, @conformance.MessageFormat2Input::{
          locale: "en",
          source: "Hello",
          bidi_isolation: None,
          tags: [],
          params_json: None,
        }),
        @conformance.MessageFormat2Result::Formatted("Hello"),
      )
    None => fail("MF2 trait 未从登记表取出")
  }
}
