# ParkEase Manager - Smart Parking Management System

A comprehensive parking management solution with Flutter mobile app and Node.js backend.

## 🚀 Features

### Mobile App (Flutter)
- ✅ Vehicle entry/exit management with 13 Indian vehicle types
- ✅ Bluetooth thermal printer support with auto-print
- ✅ Offline-first architecture with cloud sync
- ✅ JWT authentication with multi-device support
- ✅ 3-day trial period for guest users
- ✅ Real-time analytics and reports
- ✅ QR code generation on receipts
- ✅ Customizable business settings

### Backend (Node.js)
- 🔐 JWT authentication with refresh tokens
- 🗄️ PostgreSQL database integration
- 📱 Multi-device session management
- 🔄 Data synchronization with conflict resolution
- 📊 Analytics and dashboard APIs
- 🛡️ Role-based access control

## 🛠️ Tech Stack

### Frontend
- **Framework**: Flutter 3.x
- **State Management**: Provider
- **Database**: SQLite (local)
- **Printing**: Bluetooth Serial & ESC/POS

### Backend
- **Runtime**: Node.js 18+
- **Framework**: Express.js
- **Database**: PostgreSQL
- **Authentication**: JWT with refresh tokens

## 📱 Mobile App Setup

### Prerequisites
- Flutter SDK 3.x
- Android Studio / VS Code
- Android device/emulator

### Installation

```bash
# Clone repository
git clone https://github.com/deepanshuvermaa/parking-manager.git
cd parking-manager

# Install dependencies
flutter pub get

# Run app
flutter run
```

### Build APK

```bash
# Debug build
flutter build apk --debug

# Release build
flutter build apk --release
```

## 🖥️ Backend Setup

### Prerequisites
- Node.js 18+
- PostgreSQL

### Installation

```bash
# Navigate to backend
cd backend

# Install dependencies
npm install

# Setup environment
cp .env.example .env
# Edit .env with your configuration

# Setup database
npm run setup-db

# Start server
npm start
```

## 📝 Default Credentials

### Admin User
- **Username**: admin
- **Password**: password

## 👨‍💻 Developer

**Deepanshu Verma**
- GitHub: [@deepanshuvermaa](https://github.com/deepanshuvermaa)

---

© 2025 ParkEase Manager. All rights reserved.