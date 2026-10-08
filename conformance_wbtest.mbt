///|
test "label 与 all 一一对应，没有未覆盖的套件" {
  let labels = Suite::all().map(s => s.label())
  assert_eq(labels, ["decimal", "datetime", "message-format-2"])
}

///|
test "套件数量与枚举构造器数量一致（新增套件时必须同步 all）" {
  let seen : Map[String, Unit] = Map([])
  for s in Suite::all() {
    assert_false(seen.contains(s.label()))
    seen[s.label()] = ()
  }
  assert_eq(seen.length(), 3)
}
