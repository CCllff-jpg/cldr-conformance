///|
test "目录共 16 个条目，分档为 12 Fast + 4 Full" {
  let all = catalog_all()
  assert_eq(all.length(), 16)
  assert_eq(catalog_fast().length(), 12)
  assert_eq(catalog_full().length(), 16)
}

///|
test "目录条目的本地路径与 URL 都不重复" {
  let paths : Map[String, Unit] = Map([])
  let urls : Map[String, Unit] = Map([])
  for item in catalog_all() {
    assert_false(paths.contains(item.path))
    assert_false(urls.contains(item.url))
    paths[item.path] = ()
    urls[item.url] = ()
  }
  assert_eq(paths.length(), 16)
  assert_eq(urls.length(), 16)
}

///|
test "URL 指向固定的 CLDR ref，且与本地路径一一对应" {
  let base = "https://raw.githubusercontent.com/unicode-org/cldr/\{cldr_ref()}/common/testData"
  for item in catalog_all() {
    assert_true(item.url.has_prefix(base))
    assert_true(item.path.has_prefix("fixtures/"))
    // url = base + "/" + (path 去掉 fixtures/ 的部分)
    let rel_from_url = item.url[base.length():].to_owned()
    let rel_from_path = item.path["fixtures/".length():].to_owned()
    assert_eq(rel_from_url, "/\{rel_from_path}")
  }
}

///|
test "suite 取值限定在三个已知套件内" {
  let known = ["decimal", "datetime", "message-format-2"]
  for item in catalog_all() {
    assert_true(known.contains(item.suite))
  }
}

///|
test "快速档全部是 Fast，全量档包含两者" {
  for item in catalog_fast() {
    assert_eq(item.tier, Fast)
  }
  assert_true(catalog_full().any(item => item.tier == Full))
}

///|
test "覆盖三个套件，每类都至少有一个文件" {
  let suites : Map[String, Int] = Map([])
  for item in catalog_all() {
    let n = match suites.get(item.suite) {
      Some(count) => count
      None => 0
    }
    suites[item.suite] = n + 1
  }
  assert_eq(suites.length(), 3)
  assert_true(suites["decimal"] > 0)
  assert_true(suites["datetime"] > 0)
  assert_true(suites["message-format-2"] > 0)
}
