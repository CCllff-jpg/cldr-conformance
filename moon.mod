// cldr-conformance —— CLDR 一致性基准与差分对拍工具链
// 配置参考: https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html

name = "CCllff-jpg/cldr-conformance"

version = "0.1.0"

readme = "README.mbt.md"

// 创建 GitHub 仓库后填入，例如 https://github.com/CCllff-jpg/cldr-conformance

repository = ""

license = "Apache-2.0"

keywords = [
  "cldr",
  "i18n",
  "l10n",
  "conformance",
  "unicode",
  "testing",
  "devtools",
]

// 报告站点与 CLI 都以原生后端为主；wasm/js 后端用于静态演示

preferred_target = "native"

description = "CLDR conformance benchmark and differential tester for MoonBit i18n implementations"
