///|
test "适配器默认视为已安装" {
  let info = AdapterInfo::new(name="zlhahaha/moonlocale")
  assert_true(info.installed)
  assert_eq(info.name, "zlhahaha/moonlocale")
}

///|
test "未安装的适配器可以被显式标记" {
  let info = AdapterInfo::new(name="lampclaw/i18n", installed=false)
  assert_false(info.installed)
}
