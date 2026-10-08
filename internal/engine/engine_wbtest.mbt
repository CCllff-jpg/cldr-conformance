///|
test "默认只跑快速档，全量档必须显式开启" {
  assert_false(EngineConfig::default().full)
}
