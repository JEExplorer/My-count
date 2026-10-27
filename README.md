# Afghan Business Pro

An offline-first Flutter app starter for small shops in Afghanistan. The interface is in Dari/Persian and amounts are shown in AFN (افغانی).

## Features included
- Local SQLite database (data remains after closing the app)
- Product inventory: add, edit, delete, search, stock count and low-stock warning
- Sales: create sale, reduce stock automatically, record total and recent sales
- Customer debts: record debt, record repayment, see remaining balance
- Dashboard with stock value, sales total, low-stock count and outstanding debt
- CSV export/share for products, sales and debts
- Basic validation and confirmation before destructive actions
- RTL layout and responsive Material 3 interface

## Important
This is a substantial starter project, but it has **not been compiled or tested on a physical Android phone in this environment**. Before selling it, test all flows, add your own branding, and have a developer review security, backups, accounting rules and local requirements. It is offline-only; there is no cloud sync, login, multi-user system, invoice printer integration, or automatic backup yet.

## Build APK
1. Install Flutter SDK and Android Studio.
2. Open a terminal in this project folder.
3. Run:
   ```bash
   flutter create . --platforms=android
   flutter pub get
   flutter analyze
   flutter run
   ```
4. To build a release APK:
   ```bash
   flutter build apk --release
   ```
5. The APK will usually be at:
   `build/app/outputs/flutter-apk/app-release.apk`

If `flutter create .` asks to overwrite existing files, keep the existing `lib/` and `pubspec.yaml` files. Review the generated Android package/application ID before publishing.

## Database
The app uses a local SQLite database. Uninstalling the app may remove its data, so add and test a backup/restore feature before relying on it for real business records.


## FlutLab import note
This ZIP includes Android and iOS platform scaffolding because some online importers validate both directories even for Android-only work. Platform scaffolding may still need regeneration/adjustment by the online build service.
