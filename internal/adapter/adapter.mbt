///|
/// 适配器登记信息。`id` 是 CLI 使用的稳定标识，`name` 用于展示。
/// 未安装或未被选择的实现会映射为 `CaseOutcome::NotInstalled`。
pub(all) struct AdapterInfo {
  id : String
  name : String
  installed : Bool
  capabilities : @conformance.AdapterCapabilities
} derive(Debug, Eq)

///|
pub fn AdapterInfo::new(
  id~ : String,
  name~ : String,
  capabilities~ : @conformance.AdapterCapabilities,
  installed~ : Bool = true,
) -> AdapterInfo {
  { id, name, installed, capabilities, }
}

///|
/// 注册失败或选择了不存在的适配器。
pub(all) suberror AdapterRegistryError {
  EmptyId
  DuplicateId(id~ : String)
  UnknownId(id~ : String)
  MissingHandler(id~ : String, capability~ : String)
  UnexpectedHandler(id~ : String, capability~ : String)
} derive(Debug)

///|
struct RegistryEntry {
  info : AdapterInfo
  number : &@conformance.NumberAdapter?
  datetime : &@conformance.DatetimeAdapter?
  message_format_2 : &@conformance.MessageFormat2Adapter?
}

///|
/// 已登记的适配器及其公开 trait 对象。内部引擎通过稳定 ID 取得对应 handler。
pub struct AdapterRegistry {
  entries : Array[RegistryEntry]
}

///|
pub fn AdapterRegistry::new() -> AdapterRegistry {
  { entries: [], }
}

///|
/// 登记适配器，并校验能力声明与提供的 trait 对象一致。
pub fn AdapterRegistry::register(
  self : AdapterRegistry,
  info : AdapterInfo,
  number~ : &@conformance.NumberAdapter? = None,
  datetime~ : &@conformance.DatetimeAdapter? = None,
  message_format_2~ : &@conformance.MessageFormat2Adapter? = None,
) -> Unit raise AdapterRegistryError {
  if info.id == "" {
    raise AdapterRegistryError::EmptyId
  }
  if self.find(info.id) is Some(_) {
    raise AdapterRegistryError::DuplicateId(id=info.id)
  }

  let decimal = info.capabilities.contains(
    @conformance.AdapterCapability::Decimal,
  )
  validate_handler(info.id, "decimal", decimal, number)

  let datetime_declared = info.capabilities.contains(
      @conformance.AdapterCapability::DatetimeSkeleton,
    ) ||
    info.capabilities.contains(@conformance.AdapterCapability::DatetimeFormat)
  validate_handler(info.id, "datetime", datetime_declared, datetime)

  let message_format_2_declared = info.capabilities.contains(
    @conformance.AdapterCapability::MessageFormat2,
  )
  validate_handler(
    info.id,
    "message-format-2",
    message_format_2_declared,
    message_format_2,
  )

  self.entries.push({ info, number, datetime, message_format_2, })
}

///|
fn[T] validate_handler(
  id : String,
  capability : String,
  declared : Bool,
  handler : T?,
) -> Unit raise AdapterRegistryError {
  match (declared, handler) {
    (true, None) => raise AdapterRegistryError::MissingHandler(id~, capability~)
    (false, Some(_)) =>
      raise AdapterRegistryError::UnexpectedHandler(id~, capability~)
    _ => ()
  }
}

///|
/// 按稳定 ID 查找登记信息。
pub fn AdapterRegistry::find(
  self : AdapterRegistry,
  id : String,
) -> AdapterInfo? {
  for entry in self.entries {
    if entry.info.id == id {
      return Some(entry.info)
    }
  }
  None
}

///|
/// 选择指定适配器；重复 ID 去重，未知 ID 报错。
pub fn AdapterRegistry::select(
  self : AdapterRegistry,
  ids : Array[String],
) -> Array[AdapterInfo] raise AdapterRegistryError {
  let selected : Array[AdapterInfo] = []
  for id in ids {
    if !selected.any(info => info.id == id) {
      match self.find(id) {
        Some(info) => selected.push(info)
        None => raise AdapterRegistryError::UnknownId(id~)
      }
    }
  }
  selected
}

///|
/// 返回所有已安装适配器，作为 CLI 的默认选择。
pub fn AdapterRegistry::installed(self : AdapterRegistry) -> Array[AdapterInfo] {
  self.entries.filter(entry => entry.info.installed).map(entry => entry.info)
}

///|
/// 适配器未选入或未安装时返回 `NotInstalled`；没有声明该能力时返回 `Unsupported`；
/// `None` 表示可执行。这样缺失能力不会被算成一致性失败。
pub fn AdapterRegistry::unavailable_outcome(
  self : AdapterRegistry,
  id : String,
  selected_ids : Array[String],
  capability : @conformance.AdapterCapability,
) -> @conformance.CaseOutcome? raise AdapterRegistryError {
  match self.find(id) {
    None => raise AdapterRegistryError::UnknownId(id~)
    Some(info) =>
      if !selected_ids.contains(id) || !info.installed {
        Some(@conformance.CaseOutcome::NotInstalled)
      } else if !info.capabilities.contains(capability) {
        Some(@conformance.CaseOutcome::Unsupported(feature=capability.label()))
      } else {
        None
      }
  }
}

///|
/// 取数字适配器 trait 对象；未知 ID 或未登记该 handler 时返回 `None`。
pub fn AdapterRegistry::number_adapter(
  self : AdapterRegistry,
  id : String,
) -> &@conformance.NumberAdapter? {
  for entry in self.entries {
    if entry.info.id == id {
      return entry.number
    }
  }
  None
}

///|
/// 取日期适配器 trait 对象；未知 ID 或未登记该 handler 时返回 `None`。
pub fn AdapterRegistry::datetime_adapter(
  self : AdapterRegistry,
  id : String,
) -> &@conformance.DatetimeAdapter? {
  for entry in self.entries {
    if entry.info.id == id {
      return entry.datetime
    }
  }
  None
}

///|
/// 取 MF2 适配器 trait 对象；未知 ID 或未登记该 handler 时返回 `None`。
pub fn AdapterRegistry::message_format_2_adapter(
  self : AdapterRegistry,
  id : String,
) -> &@conformance.MessageFormat2Adapter? {
  for entry in self.entries {
    if entry.info.id == id {
      return entry.message_format_2
    }
  }
  None
}
