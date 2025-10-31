
# Where its at

**Where its at** is an offline-first Flutter app for Android that helps you track items you lend to others (with due dates and contacts) and where you stash your own items (with photos of their locations). No backend required—your data is stored locally and securely. Features include notifications, biometric/PIN lock, sharing, CSV/PDF export, and more.

## Android Release & Play Console Checklist

### Keystore & Signing

1. Generate a keystore:
	 ```sh
	 keytool -genkey -v -keystore release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias whereitsat
	 ```
2. Place `release-key.jks` in `android/app/`.
3. Edit `android/app/build.gradle.kts`:
	 ```kotlin
	 signingConfigs {
		 release {
			 storeFile = file("release-key.jks")
			 storePassword = "your-password"
			 keyAlias = "whereitsat"
			 keyPassword = "your-password"
		 }
	 }
	 buildTypes {
		 release {
			 signingConfig = signingConfigs.getByName("release")
		 }
	 }
	 ```
4. Build release APK/AAB:
	 ```sh
	 flutter build appbundle --release
	 flutter build apk --release
	 ```

### Play Console Checklist

- [ ] App bundle uploaded
- [ ] VersionCode/VersionName match pubspec.yaml
- [ ] Keystore configured for release
- [ ] Privacy policy uploaded
- [ ] Screenshots and description added
- [ ] Permissions declared (camera, notifications, storage)
- [ ] Manual tests passed (see QA/checklist.md)
