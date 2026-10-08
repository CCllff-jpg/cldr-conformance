///|
/// 从命令行参数中取出 `name` 后面紧跟的值；缺失时返回 `None`。
///
/// 只支持 `--flag value` 形式，不支持 `--flag=value`——分档、重试等编排逻辑在 D2-F3 落地。
fn flag_value(args : Array[String], name : String) -> String? {
  let mut result : String? = None
  let mut done = false
  for i, arg in args {
    if !done && arg == name && i + 1 < args.length() {
      result = Some(args[i + 1])
      done = true
    }
  }
  result
}

///|
/// 参数中是否存在该开关（无值形式，例如 `--verify`）。
fn has_flag(args : Array[String], name : String) -> Bool {
  let mut found = false
  for arg in args {
    if arg == name {
      found = true
    }
  }
  found
}
