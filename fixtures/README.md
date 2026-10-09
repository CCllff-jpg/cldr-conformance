# fixtures/

CLDR 官方测试数据的本地快照，用于**离线可复现**地跑一致性基准。

- 数据基线（不可变 tag）、文件清单、许可证：[`../DATA-SOURCES.md`](../DATA-SOURCES.md)
- 摘要的**权威记录**：本目录的 `SOURCES.json`（由 `--sync` 生成、由 `--verify` 复核）
- 数据许可证：[Unicode License v3](https://www.unicode.org/license.txt)（与代码的 Apache-2.0 不同，请勿混用）

## 当前内容

```
fixtures/
├── SOURCES.json                       # 12 条快速档记录：url / bytes / sha256 / tier
├── decimal/
│   ├── decimals.tsv
│   └── decimals_modern_locales.tsv
├── datetime/
│   ├── datetime.json
│   ├── skeletons.tsv
│   └── skeletons_all_calendars.tsv
└── messageFormat/tests/
    ├── syntax.json  syntax-errors.json  data-model-errors.json
    ├── pattern-selection.json  fallback.json
    └── bidi.json  u-options.json
```

## 分档规则

- **快速档（Fast，12 个，约 251 KB）**：入库，保证 clone 下来就能**离线**跑 `--verify` 与后续解析。
- **全量档（Full，4 个，约 721 KB）**：**不入库**（已列入 `.gitignore`），
  需要时用 `moon run cmd/fetch-data -- --sync --full` 拉取。全量档文件若已下载，
  会被写进 `SOURCES.json`；在没下载它的机器上 `--verify` 会如实报 `Missing`。

## 注意事项

- **不要手工编辑这里的文件**：任何修改都会让结论与官方基准失去可比性。数据一律通过 `cmd/fetch-data` 获取。
- 所有文件都以固定 tag（`release-49-beta3`）拉取，URL 不可变，因此摘要可以长期复核。
