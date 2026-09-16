# DriveRent Manager v7

Android-only self-drive car rental manager. Local XLSX database.

## Codemagic
The build workflow creates the Android wrapper and explicitly sets Android compileSdk to 36 before building the release APK.

Upload this project to GitHub with `pubspec.yaml` and `codemagic.yaml` at the repository root, then run the `android-release` workflow in Codemagic.
