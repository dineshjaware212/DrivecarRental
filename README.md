# DriveRent Manager v4

Full Android-only self-drive rental manager prepared for online APK building.

Features:
- Dashboard
- Cars add/list/delete
- Customers add/list/delete
- Bookings create/list/delete
- Payments record/list/delete
- Maintenance record/list/delete
- Local XLSX workbook in app storage
- Import XLSX
- Backup/share XLSX
- INR
- Codemagic cloud build
- GitHub Actions cloud build
- No web panel

Online build:
1. Upload this folder to a GitHub repository.
2. Connect the repository to Codemagic.
3. Start the android-release workflow.
4. Download app-release.apk from Artifacts.

For Play Store release, configure a private Android signing key in the build service.
