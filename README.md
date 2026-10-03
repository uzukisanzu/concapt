# concapt

An Android and Windows app that captures Gakuen Idolmaster contest rehearsal results. On Android a floating bubble triggers the capture; on Windows a global hotkey captures a chosen window. Each capture reads the nine member scores with on-device OCR, checks each stage's sum, and adds the run to a session. Sessions show per-slot statistics, histograms, and CSV export.

## Build

```sh
flutter pub get
flutter test
flutter build apk --release
flutter run -d windows
```

Android (`minSdk` 26) and Windows 10 2004+. The Windows build runs from the repo.

## Docs

- `PRODUCT.md`: users, terminology, brand
- `DESIGN.md`: the design system
- `docs/superpowers/specs/`: the design spec
- `docs/manual-test-checklist.md`: on-device checks

## License

MIT, see `LICENSE`. The bundled Roboto fonts are under the SIL Open Font License (`assets/fonts/OFL.txt`).

Gakuen Idolmaster is a trademark of Bandai Namco Entertainment. This project is unofficial and not affiliated with it.
