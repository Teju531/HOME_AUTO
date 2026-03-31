# IoT Smart Home App Icon

## Current Setup
The app launcher icon is configured in `pubspec.yaml` with flutter_launcher_icons.

## To Generate Custom Launcher Icon:

### Option 1: Use an existing icon
1. Place your app icon image (1024x1024 PNG) at `assets/app_icon.png`
2. Run: `flutter pub get`
3. Run: `flutter pub run flutter_launcher_icons`

### Option 2: Use the default Flutter icon
The app currently uses the default Flutter launcher icons located in:
- `android/app/src/main/res/mipmap-*/ic_launcher.png`

### Option 3: Create a simple icon online
1. Visit: https://icon.kitchen or https://romannurik.github.io/AndroidAssetStudio/
2. Create an icon with:
   - Background color: #5E60CE (purple)
   - Icon: Home symbol
   - Text: "IoT" or home icon
3. Download and place in `assets/logo.jpeg`
4. Run the commands from Option 1

## Current Icon Theme
- Primary Color: #5E60CE (Purple)
- Icon Style: Home/Smart Home theme
- App Name: Apsis Smart Home
