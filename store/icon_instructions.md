# App Icon Generation

- Use [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) for automated icon generation.
- Recommended: Create a vector SVG icon (e.g., box with a checkmark, or hand passing an item).
- Place SVG in `assets/icon.svg`.
- Configure `pubspec.yaml` as follows:

```yaml
flutter_icons:
  android: true
  ios: true
  image_path: "assets/icon.svg"
  adaptive_icon_background: "#ffffff"
  adaptive_icon_foreground: "assets/icon.svg"
```
- Run:
```
flutter pub run flutter_launcher_icons:main
```
- Review generated icons in `/android/app/src/main/res/` and `/ios/Runner/Assets.xcassets/AppIcon.appiconset/`.
