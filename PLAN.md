You are a senior Flutter engineer specializing in dependency resolution, migration of legacy Flutter projects, and Firebase mobile architecture.

## 🎯 OBJECTIVE

Fix and modernize a Flutter project called `times_up_flutter` by:

1. Resolving all dependency conflicts
2. Fixing version solving failures (pubspec.yaml issues)
3. Updating dependencies to compatible stable versions
4. Ensuring the project builds and runs successfully on Flutter stable (latest version)
5. Keeping Firebase functionality intact

---

## 📌 CONTEXT

The project is currently broken due to:

- Mixed outdated and modern Flutter dependencies
- Version conflicts between:
  - `package_info_plus`
  - `device_info_plus`
  - `flutter_local_notifications`
  - `timezone`
  - `http`
- Windows platform dependency conflicts (`win32` version mismatch)
- Pub resolver failing with dependency graph conflicts

Current Flutter version:
- Flutter stable (3.41+ or newer)

Project is a Flutter + Firebase app for parental control / screen time tracking.

---

## 🚨 CURRENT MAIN ERROR CATEGORY

### Dependency conflicts:

- `package_info_plus >=10.x` requires `win32 ^6.x`
- `device_info_plus ^8.x` requires `win32 <5.0.0`
- `flutter_local_notifications >=21.x` requires `timezone ^0.11.x`
- `package_info_plus ^3.x` requires `http ^0.13.x`
- `timezone >=0.11.x` requires `http ^1.x`

👉 Result: dependency resolution failure

---

## 🛠️ REQUIRED TASKS

### 1. Dependency Graph Fix
- Analyze all dependencies in `pubspec.yaml`
- Identify incompatible version clusters
- Choose ONE consistent ecosystem version set

Rules:
- Prefer stable, non-beta versions
- Avoid mixing major incompatible ecosystems
- Ensure `win32` compatibility is resolved

---

### 2. Version Alignment Strategy

Create a consistent dependency set:

- `package_info_plus`
- `device_info_plus`
- `flutter_local_notifications`
- `timezone`
- `http`

Ensure:
- All dependencies resolve together
- No conflicting transitive dependencies
- No platform-specific version mismatches

---

### 3. Windows Dependency Fix

- Resolve `win32` version conflict
- Either:
  - Align versions properly OR
  - Downgrade conflicting packages OR
  - Remove unnecessary Windows-specific constraints if safe

---

### 4. Upgrade Strategy

Safely upgrade dependencies:

- Firebase packages
- UI packages
- Utility packages

But:
- Do NOT break Android build
- Do NOT break Firebase auth/storage/messaging

---

### 5. Clean & Build Validation

After changes ensure:

```bash
flutter clean
flutter pub get
flutter analyze
flutter run