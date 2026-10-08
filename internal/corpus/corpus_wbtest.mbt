///|
test "空语料统计" {
  let stats = CorpusStats::empty()
  assert_true(stats.is_empty())
  assert_eq(stats.locales, 0)
}

///|
test "有数据时不再为空" {
  let stats : CorpusStats = { cases: 1, locales: 1, }
  assert_false(stats.is_empty())
}
