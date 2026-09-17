@echo off
setlocal
cd /d "%~dp0"

where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter is not installed or is not available in PATH.
  pause
  exit /b 1
)

if not exist android\app\build.gradle if not exist android\app\build.gradle.kts flutter create --platforms=android --org com.driverent .
if errorlevel 1 goto :failed

if exist android\app\build.gradle.kts powershell -NoProfile -Command "$p='android/app/build.gradle.kts'; $c=Get-Content $p -Raw; $c=$c -replace 'compileSdk = flutter.compileSdkVersion','compileSdk = 36'; $c=$c -replace 'compileSdk = [0-9]+','compileSdk = 36'; Set-Content $p $c"
if exist android\app\build.gradle powershell -NoProfile -Command "$p='android/app/build.gradle'; $c=Get-Content $p -Raw; $c=$c -replace 'compileSdkVersion flutter.compileSdkVersion','compileSdkVersion 36'; $c=$c -replace 'compileSdkVersion [0-9]+','compileSdkVersion 36'; Set-Content $p $c"

flutter clean
if errorlevel 1 goto :failed
flutter pub get
if errorlevel 1 goto :failed
flutter build apk --release --no-pub
if errorlevel 1 goto :failed

echo.
echo APK created at: build\app\outputs\flutter-apk\app-release.apk
pause
exit /b 0

:failed
echo.
echo APK build failed. Review the error shown above.
pause
exit /b 1
