# Test fixtures

## `tr.pack`

A synthetic region pack produced by the pipeline's fixture generator — **not** real
Turkey data. Shape (see `tools/waymark_pack/fixture.py`):

- 2 tier-1 units (`Test İli A`, `Test İli B`)
- 3 tier-2 units — `İlçe C1` contains an enclave (inner ring); `İlçe C2` *is* that
  enclave; `İlçe D1` is a plain district under `Test İli B`
- 5 settlements
- `tr` articles for all 5 admin units, `en` for 2 (so the language-fallback and
  coverage paths have something to exercise)

It is committed as a binary so `swift test` needs no Python. Regenerate after any
schema (spec 5.3) or polygon-format (spec 5.4) change:

```bash
# from the repo root, with the pipeline venv active (see tools/README.md)
python3 -m tools.build_pack \
  --config tools/config/tr.toml \
  --out Packages/GeoData/Tests/GeoDataTests/Fixtures/tr.pack \
  --fixture
```

The generator is deterministic: the same pipeline revision always produces byte-identical
output (`build_hash` in the `meta` table).
