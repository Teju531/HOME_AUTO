# IoT Home Automation Application (Flutter)

Flutter mobile app UI for managing smart home channels, devices, scenes, and user permissions.

## Features

- Onboarding and authentication flow
- Channel onboarding (QR and Wi-Fi paths)
- Device management screens
- Scene management screens
- User and permission management screens
- Account and profile-related screens
- Camera/QR and runtime permission support

## Tech Stack

- Flutter (Dart)
- `mobile_scanner` for QR scanning
- `permission_handler` for app permissions

## Project Structure

```text
lib/
  main.dart
  constants/
  models/
  screens/
assets/
android/
ios/
```

## Prerequisites

- Flutter SDK (3.x recommended)
- Dart SDK (bundled with Flutter)
- Android Studio or VS Code with Flutter extensions
- Android SDK / emulator (or physical Android device)

## Setup

```bash
flutter pub get
```

## Run

```bash
flutter run
```

To list available devices:

```bash
flutter devices
```

If needed, you can also use the helper script in this repo:

```powershell
.\connect_device.bat
```

## Build APK

```bash
flutter build apk --release
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Main Routes

Defined in `lib/main.dart`, including:

- `/onboarding`
- `/login`
- `/signup`
- `/home`
- `/my-channels`
- `/channel-home`
- `/add-device`
- `/my-devices`
- `/my-scenes`
- `/users`
- `/user-permissions`
- `/my-account`

## Notes

- App is currently set to portrait-only orientation.
- App icon is configured through `flutter_launcher_icons` using `assets/logo.png`.
