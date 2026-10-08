///|
/// 数据分档。
///
/// `Fast` 档入库，保证离线可复现；`Full` 档体积大，只在 `--full` 时下载
/// （见 开发方案.md §3.1）。
pub(all) enum Tier {
  Fast
  Full
} derive(Debug, Eq, ToJson, FromJson)

///|
/// 清单中的一条记录：一个 fixture 的来源与内容摘要。
///
/// `suite` 取 `Suite::label()` 的值（`decimal` / `datetime` / `message-format-2`）。
/// 这里刻意用字符串而不是枚举：`internal/*` 不能反向依赖 facade 包，
/// 否则 facade 将来引用 `internal/corpus` 时会形成循环依赖（见 DESIGN.md D4）。
pub(all) struct SourceFile {
  suite : String
  path : String
  url : String
  sha256 : String
  bytes : Int
  tier : Tier
} derive(Debug, Eq, ToJson, FromJson)

///|
/// 数据清单：`fixtures/SOURCES.json` 的模型。
///
/// 刻意不记录生成时间：清单要能在 git 里稳定 diff，时间戳只会制造噪声。
pub(all) struct Manifest {
  cldr_version : String
  files : Array[SourceFile]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// 清单读写与校验过程中的失败。
pub(all) suberror SourceError {
  ManifestNotFound(path~ : String)
  /// 校验发现不一致的条目数量（> 0 即失败，用于 CI 退出码）。
  VerificationFailed(mismatches~ : Int)
} derive(Debug)

///|
/// 稳定的 JSON 文本（缩进 2 空格），便于人工审阅与 git diff。
pub fn Manifest::to_json_string(self : Manifest) -> String {
  @json.to_json(self).stringify(indent=2)
}

///|
/// 从 JSON 文本解析清单。
pub fn manifest_from_json_string(text : StringView) -> Manifest raise {
  @json.from_json(@json.parse(text))
}

///|
/// 读取清单文件；文件不存在时抛 `SourceError::ManifestNotFound`。
pub async fn load_manifest(path : String) -> Manifest {
  if !@fs.exists(path) {
    raise SourceError::ManifestNotFound(path~)
  }
  manifest_from_json_string(@fs.read_file(path).text())
}

///|
/// 写入清单文件（自动创建父目录）。
pub async fn save_manifest(path : String, manifest : Manifest) -> Unit {
  match parent_dir(path) {
    Some(dir) => @fs.mkdir(dir, recursive=true, allow_exist=true)
    None => ()
  }
  @fs.write_file(path, manifest.to_json_string())
}
