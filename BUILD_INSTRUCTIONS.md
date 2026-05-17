# ParkEase Manager - Build Instructions

## 🚀 Quick Start

### Option 1: Build Everything (Android + Windows)
```batch
build_release.bat
```
This creates a timestamped release in `releases\` folder with both Android APK and Windows executable.

### Option 2: Build Android Only (Faster)
```batch
build_quick.bat
```
Creates `ParkEase-Android.apk` in the root folder.

### Option 3: Build Windows Only
```batch
build_windows_only.bat
```
Creates Windows release and opens the folder.

---

## 📋 Prerequisites

### Required Software
- **Flutter SDK** (3.0 or higher)
- **Android SDK** (for Android builds)
- **Visual Studio 2019/2022** (for Windows builds)
- **Git** (for version control)

### Verify Installation
```batch
flutter doctor -v
```

---

## 📦 Build Scripts Included

### 1. `build_release.bat` - Full Release Build
**What it does:**
- Cleans previous builds
- Gets latest dependencies
- Builds Android APK (release mode)
- Builds Windows executable (release mode)
- Creates timestamped release folder
- Copies all files to `releases\YYYY-MM-DD_HH-MM\`
- Generates BUILD_INFO.txt
- Opens release folder

**Output:**
```
releases\2025-12-21_13-07\
├── ParkEase-v4.3-Android-2025-12-21_13-07.apk
├── ParkEase-v4.3-Windows\
│   ├── parkease_manager.exe
│   ├── flutter_windows.dll
│   └── data\
└── BUILD_INFO.txt
```

### 2. `build_quick.bat` - Android Only (Fast)
**What it does:**
- Builds Android APK only
- Copies to root as `ParkEase-Android.apk`
- Takes ~2-3 minutes

**Output:**
```
ParkEase-Android.apk (in project root)
```

### 3. `build_windows_only.bat` - Windows Only
**What it does:**
- Builds Windows executable only
- Opens the Release folder
- Takes ~2-3 minutes

**Output:**
```
build\windows\x64\runner\Release\parkease_manager.exe
```

---

## 🔧 Manual Build Commands

### Android APK
```batch
flutter clean
flutter pub get
flutter build apk --release
```
Output: `build\app\outputs\flutter-apk\app-release.apk`

### Android App Bundle (for Play Store)
```batch
flutter build appbundle --release
```
Output: `build\app\outputs\bundle\release\app-release.aab`

### Windows Release
```batch
flutter clean
flutter pub get
flutter build windows --release
```
Output: `build\windows\x64\runner\Release\`

---

## 📱 Installation

### Android
1. Copy APK to device
2. Enable "Install from Unknown Sources"
3. Tap APK to install
4. Grant required permissions

**OR via ADB:**
```batch
adb install ParkEase-Android.apk
```

### Windows
1. Copy entire `Release` folder to target machine
2. Run `parkease_manager.exe`
3. No installation needed - portable app

---

## 🐛 Troubleshooting

### Build Fails - "Flutter not found"
**Solution:**
```batch
where flutter
```
If not found, add Flutter to PATH or run from Flutter directory.

### Android Build Fails - SDK not found
**Solution:**
```batch
flutter doctor --android-licenses
```
Accept all licenses.

### Windows Build Fails - Visual Studio error
**Solution:**
- Install Visual Studio 2019 or 2022
- Include "Desktop development with C++" workload
- Restart and rebuild

### Build is slow
**Solution:**
- First build takes longer (5-10 minutes)
- Subsequent builds are faster (2-3 minutes)
- Use `build_quick.bat` for faster Android-only builds

---

## 📊 Build Times (Approximate)

| Build Type | First Time | Subsequent |
|------------|------------|------------|
| Android Only | 5-7 min | 2-3 min |
| Windows Only | 5-8 min | 2-3 min |
| Both Platforms | 10-15 min | 4-6 min |

---

## 🎯 Release Checklist

Before building a release:

- [ ] Test app on emulator/device
- [ ] Verify all features work
- [ ] Check version number in `pubspec.yaml`
- [ ] Update CHANGELOG.md
- [ ] Commit all changes to Git
- [ ] Run `build_release.bat`
- [ ] Test both APK and Windows builds
- [ ] Create release notes
- [ ] Distribute files

---

## 📂 Project Structure

```
parkease_manager/
├── build_release.bat         ← Full build script
├── build_quick.bat           ← Android-only build
├── build_windows_only.bat    ← Windows-only build
├── BUILD_INSTRUCTIONS.md     ← This file
├── releases/                 ← Generated releases
│   └── 2025-12-21_13-07/
├── build/                    ← Build output
│   ├── app/
│   │   └── outputs/
│   │       └── flutter-apk/
│   │           └── app-release.apk
│   └── windows/
│       └── x64/
│           └── runner/
│               └── Release/
├── lib/                      ← Source code
├── android/                  ← Android config
├── windows/                  ← Windows config
└── pubspec.yaml             ← Dependencies
```

---

## 🆕 What's New in v4.3

### Taxi Service Feature
- Complete taxi booking management
- 13 fields: ticket, customer, vehicle, driver, trip details
- Status workflow: booked → ongoing → completed
- Separate from parking operations
- Thermal receipt printing

### USB Printer Support
- Fixed auto-connect issue
- Works on Android, Tablets, Desktop
- Proper USB vs Bluetooth detection

### 5th Dashboard Button
- Orange "Taxi Service" button
- Queue with 4 tabs (All, Booked, Ongoing, Completed)
- Create, edit, complete bookings

---

## 📞 Support

For build issues or questions, check:
1. `flutter doctor -v` for system diagnostics
2. Build logs in console output
3. Error messages in the terminal

---

**Ready to build? Double-click `build_release.bat` to start!**
