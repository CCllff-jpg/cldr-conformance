///|
/// 从命令行参数中取出 `name` 后面紧跟的值；缺失时返回 `None`。
///
/// 只支持 `--flag value` 形式，不支持 `--flag=value`——D2-F1 刻意保持最小实现，
/// 参数校验、`--verify`、`--full` 等编排逻辑在 D2-F3 落地。
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
