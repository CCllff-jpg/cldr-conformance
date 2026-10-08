///|
/// 一次抓取的产物。
///
/// `sha256` 是对**实际写入磁盘的字节**计算的摘要，因此可以直接作为
/// `fixtures/SOURCES.json` 的校验值，用于离线复现。
pub(all) struct FetchResult {
  url : String
  path : String
  bytes : Int
  sha256 : String
} derive(Debug, Eq)

///|
/// 抓取过程中的失败。
pub(all) suberror FetchError {
  /// 服务端返回了非 2xx 状态码。
  UnexpectedStatus(url~ : String, code~ : Int)
} derive(Debug)

///|
/// 计算字节的 SHA-256 十六进制摘要（小写）。
pub fn sha256_hex(data : Bytes) -> String {
  let digest = @sha256.Digest::new()
  for byte in data {
    digest.write(byte)
  }
  digest.check_sum()
}

///|
/// 取路径的父目录；路径中没有任何分隔符时返回 `None`。
///
/// `/` 与 `\` 都视为分隔符（Windows 与 POSIX 皆可）。
pub fn parent_dir(path : String) -> String? {
  let slash = path.rev_find("/")
  let backslash = path.rev_find("\\")
  let last : Int? = match (slash, backslash) {
    (Some(a), Some(b)) => Some(if a > b { a } else { b })
    (Some(a), None) => Some(a)
    (None, Some(b)) => Some(b)
    (None, None) => None
  }
  match last {
    None => None
    Some(0) => Some("/")
    Some(index) => Some(path[:index].to_owned())
  }
}

///|
/// 把 `url` 下载到本地 `dest`，自动创建父目录，返回字节数与内容摘要。
///
/// - 只接受 2xx；其他状态码抛 `FetchError::UnexpectedStatus`。
/// - 摘要按写入的字节计算，保证与磁盘内容一致（便于后续 `--verify` 对拍）。
pub async fn fetch_to_file(url : String, dest : String) -> FetchResult {
  let (response, body) = @http.get(url)
  if response.code < 200 || response.code >= 300 {
    raise FetchError::UnexpectedStatus(url~, code=response.code)
  }
  let bytes = body.binary()
  match parent_dir(dest) {
    Some(dir) => @fs.mkdir(dir, recursive=true, allow_exist=true)
    None => ()
  }
  @fs.write_file(dest, bytes)
  { url, path: dest, bytes: bytes.length(), sha256: sha256_hex(bytes), }
}
