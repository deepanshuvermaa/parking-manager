# Java Installation Guide for Android Builds

## ⚠️ Problem
Android build failed with:
```
ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.
```

## ✅ Solution: Install Java JDK

### Quick Install (Recommended)

**Download Java 17 (LTS):**
https://www.oracle.com/java/technologies/downloads/#java17

**OR use OpenJDK (free):**
https://adoptium.net/temurin/releases/?version=17

### Installation Steps:

1. **Download** installer (Windows x64 MSI)
2. **Run** installer with default settings
3. **Restart** Command Prompt/PowerShell
4. **Verify** installation:
   ```cmd
   java -version
   ```
   Should show: `java version "17.x.x"`

### Set JAVA_HOME (if needed):

1. Press `Win + X`, select "System"
2. Click "Advanced system settings"
3. Click "Environment Variables"
4. Under "System variables", click "New":
   - Variable name: `JAVA_HOME`
   - Variable value: `C:\Program Files\Java\jdk-17` (or your install path)
5. Edit "Path" variable, add:
   - `%JAVA_HOME%\bin`
6. Click OK, restart terminal

### Verify Setup:
```cmd
java -version
javac -version
echo %JAVA_HOME%
```

---

## 🔄 After Installing Java

Run the build script again:
```cmd
build_release.bat
```

It will now detect Java and build both Android APK and Windows EXE.

---

## 🚀 Alternative: Windows-Only Build

If you don't need Android APK right now, use:
```cmd
build_windows_only.bat
```

This skips Android and only builds Windows release (no Java needed).

---

## 📱 Quick Links

**Java 17 (Oracle):**
https://www.oracle.com/java/technologies/downloads/#java17-windows

**OpenJDK 17 (Free):**
https://adoptium.net/

**Flutter Doctor:**
```cmd
flutter doctor -v
```
Check all requirements including Java.
