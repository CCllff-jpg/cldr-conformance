# fixtures/

CLDR 官方测试数据的本地快照，用于**离线可复现**地跑一致性基准。

- 来源、版本、SHA256 与许可证：[`../DATA-SOURCES.md`](../DATA-SOURCES.md)
- 数据许可证：[Unicode License v3](https://www.unicode.org/license.txt)（与代码的 Apache-2.0 不同，请勿混用）

## 目录规划

```
fixtures/
├── SOURCES.json                  # 由 cmd/fetch-data 生成：URL / SHA256 / CLDR 版本（D2）
└── decimal/
    └── decimals.tsv              # D2 落地的第一份数据
```

## 说明

- 小文件直接入库（`decimals.tsv` 7 KB、`skeletons.tsv` 11 KB、MF2 测试 JSON 约 55 KB），保证无网络也能跑出报告。
- 大文件（`decimals_extended_numbers.tsv` 217 KB、`skeletons_random_5percent.tsv` 287 KB）不默认入库，
  由 `moon run cmd/fetch-data -- --full` 按需拉取。
- **不要手工编辑这里的文件**：任何修改都会让报告与官方基准失去可比性。数据一律通过 `cmd/fetch-data` 获取。
