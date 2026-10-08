///|
/// 单个文件的校验结果。
pub(all) enum VerifyOutcome {
  Match
  Mismatch(expected~ : String, actual~ : String)
  SizeMismatch(expected~ : Int, actual~ : Int)
  Missing
} derive(Debug, Eq)

///|
/// 一条记录的校验结果。
pub(all) struct VerifyEntry {
  file : SourceFile
  outcome : VerifyOutcome
} derive(Debug, Eq)

///|
/// 是否通过校验。
pub fn VerifyOutcome::is_ok(self : VerifyOutcome) -> Bool {
  match self {
    Match => true
    _ => false
  }
}

///|
/// 纯函数校验：比对字节与清单记录，**不触碰磁盘**，因此可以离线测试。
///
/// 先比大小再比摘要：大小不符时能给出更直观的原因，也省掉一次完整哈希。
pub fn verify_bytes(data : Bytes, expected : SourceFile) -> VerifyOutcome {
  let actual_bytes = data.length()
  if actual_bytes != expected.bytes {
    SizeMismatch(expected=expected.bytes, actual=actual_bytes)
  } else {
    let actual_sha = sha256_hex(data)
    if actual_sha != expected.sha256 {
      Mismatch(expected=expected.sha256, actual=actual_sha)
    } else {
      Match
    }
  }
}

///|
/// 读取本地文件并校验；文件不存在时返回 `Missing`。
pub async fn verify_file(expected : SourceFile) -> VerifyOutcome {
  if !@fs.exists(expected.path) {
    return Missing
  }
  verify_bytes(@fs.read_file(expected.path).binary(), expected)
}

///|
/// 按清单顺序校验全部文件。
pub async fn verify_manifest(manifest : Manifest) -> Array[VerifyEntry] {
  let entries = []
  for file in manifest.files {
    entries.push({ file, outcome: verify_file(file), })
  }
  entries
}

///|
/// 不一致的条目数量（CI 用它决定退出码）。
pub fn count_failures(entries : Array[VerifyEntry]) -> Int {
  entries.filter(entry => !entry.outcome.is_ok()).length()
}

///|
/// 渲染人类可读的校验报告（纯函数，可离线测试）。
pub fn render_verify_report(
  manifest_path : String,
  manifest : Manifest,
  entries : Array[VerifyEntry],
) -> String {
  let out = StringBuilder()
  out <+ "校验 \{manifest_path}（CLDR \{manifest.cldr_version}）\n"
  for entry in entries {
    match entry.outcome {
      Match => out <+ "  ✓ \{entry.file.path}  \{entry.file.bytes} 字节\n"
      Mismatch(expected~, actual~) => {
        out <+ "  ✗ \{entry.file.path}  摘要不一致\n"
        out <+ "      expected: \{expected}\n"
        out <+ "      actual:   \{actual}\n"
      }
      SizeMismatch(expected~, actual~) => {
        out <+ "  ✗ \{entry.file.path}  大小不符\n"
        out <+ "      expected: \{expected} 字节\n"
        out <+ "      actual:   \{actual} 字节\n"
      }
      Missing => out <+ "  ✗ \{entry.file.path}  文件缺失\n"
    }
  }
  // 末尾不带换行，交给调用方决定如何输出（CLI 用 println）
  out <+
    "共 \{entries.length()} 个文件，\{count_failures(entries)} 个不一致"
  out.to_string()
}
