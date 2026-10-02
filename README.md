# concapt

An Android app that floats a capture bubble over Gakuen Idolmaster. A tap on a contest rehearsal result screen reads the nine member scores with on-device OCR, checks each stage's sum, and adds the run to a session. Sessions show per-slot statistics, histograms, and CSV export.

## Build

```sh
flutter pub get
flutter test
flutter build apk --release
```

Android only, `minSdk` 26.

## Docs

- `PRODUCT.md`: users, terminology, brand
- `DESIGN.md`: the design system
- `docs/superpowers/specs/`: the design spec
- `docs/manual-test-checklist.md`: on-device checks
