# ParkEase Manager

**Working product demo — offline-first parking operations for real-world operators.**

ParkEase is a Flutter mobile app plus Node.js/PostgreSQL backend for vehicle entry and exit, receipts, occupancy, analytics, multi-device sessions, and multi-location operations. The system is designed for environments where connectivity, printers, and operator workflows cannot be assumed to be perfect.

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

## Product workflow

```text
Open shift → record vehicle entry → issue receipt → handle offline or printer failure → record exit → reconcile sync → review occupancy and revenue
```

The product’s differentiator is operational resilience: local capture, cloud synchronization, explicit conflict handling, device/session management, and a manual recovery path when a printer or network is unavailable.

## Verification status

- **Implemented product surface:** Flutter mobile workflow, Node.js APIs, PostgreSQL integration, authentication/session handling, printing integration, analytics, and sync-related components.
- **Founder-demo ready:** the entry-to-exit workflow can be demonstrated with a simulated offline period, a printer failure, and a later sync/reconciliation step.
- **Before production use:** complete authentication hardening, run the full test suite on supported devices, verify tenant and role isolation, configure production secrets, review database migrations, and complete an operational security review.

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

## Local development authentication

Use environment-backed seed configuration for local development only. Do not commit real credentials or ship a shared default password. A production deployment must require a first-run administrator setup or one-time password initialization before any account can log in.

## Demo walkthrough

1. Start a shift and record a vehicle entry.
2. Print or preview a receipt.
3. Simulate offline mode and record another entry.
4. Restore connectivity and show sync/reconciliation.
5. Trigger a permission-denied or printer-unavailable state and show the recovery path.
6. Close the shift and inspect occupancy and revenue analytics.

## 👨‍💻 Developer

**Deepanshu Verma**
- GitHub: [@deepanshuvermaa](https://github.com/deepanshuvermaa)

---

© 2025 ParkEase Manager. All rights reserved.