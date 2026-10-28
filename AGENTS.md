# Repository Guidelines

## Project Structure & Module Organization

This is a Flutter application. App screens and controllers live under `lib/pages/`; HTTP clients are in `lib/http/`; domain and API data types are in `lib/models/` and `lib/models_new/`; shared helpers and account/storage code are in `lib/utils/`. Static images, fonts, and shaders are under `assets/`. Platform-specific projects are in `android/`, `ios/`, `linux/`, `macos/`, and `windows/`. Tests live in `test/`, organized by utility area.

## Build, Test, and Development Commands

- `flutter pub get` resolves dependencies from `pubspec.yaml` and `pubspec.lock`.
- `flutter run` launches the app on a connected device or emulator.
- `flutter analyze` runs Dart and Flutter static analysis using `analysis_options.yaml`.
- `flutter test` runs the unit and widget tests in `test/`.
- `flutter build apk --release --no-pub` builds an Android release APK using the resolved dependencies.

## Coding Style & Naming Conventions

Use Dart formatting (`dart format`) with two-space indentation and preserve the repository’s trailing-comma style. Use `lower_snake_case.dart` filenames, `UpperCamelCase` types, and `lowerCamelCase` members. Prefer package imports (`package:PiliPlus/...`); the analyzer enforces them. Keep screen UI in its page view and controller files, and place reusable behavior in shared widgets, services, or utilities.

When changing UI, follow the patterns already used in the surrounding code: reuse the project’s styles, theme extensions, and frequently used shared widgets instead of introducing a one-off visual treatment or duplicate component.

## Testing Guidelines

Tests use Flutter’s `flutter_test` package and end in `_test.dart`; place new tests under `test/` near the feature they cover. Run focused tests during development, then `flutter test` and `flutter analyze` before submitting. There is no repository-wide coverage threshold.

## Commit & Pull Request Guidelines

Recent commit subjects use short imperative phrases, for example `Add device-local follows and favorites`. Keep commits focused and descriptive. Pull requests should explain user-visible changes, list validation commands and results, link related issues when applicable, and include screenshots for UI changes.

## Security & Configuration

Do not commit account cookies, API credentials, signing keys, or generated release artifacts. Keep local signing and environment configuration outside tracked files.
