# DriveRent Manager v9

Android-only self-drive car rental manager with a local XLSX database.

## Automatic booking totals and payment balances

Bookings use customer and car selectors. The rental total is calculated automatically from the number of rental days and the selected car's daily rate. The Payments screen shows the booking total, payments already received, and the remaining balance; the payment amount is automatically filled with the current balance and may be changed for a partial payment.

The app also prevents overlapping bookings for the same car, updates each booking to **Partially Paid** or **Paid**, displays collected and outstanding totals on the dashboard, provides a payment-method selector, and requires the customer to review and accept the terms before signing.

## Car catalog and booking confirmation

Upload a photo from each car's menu. Open the catalog from the photo icon in the app bar to view currently available cars and share a photo catalog PDF through WhatsApp.

From a booking's menu, **Confirm & message customer** creates a QR-coded confirmation PDF, stores it with the booking, marks the confirmation as completed, and opens the customer's WhatsApp chat with a prepared confirmation message. WhatsApp requires the user to tap **Send**. Use **Share QR confirmation** to attach the QR-coded PDF through WhatsApp.

## WhatsApp payment requests

The Payments screen displays the configured Google Pay QR code and UPI ID. Select a booking and use **Request INR 500 Token** or **Request Remaining**. The app calculates the current balance and shares the QR image with a professionally formatted payment request through WhatsApp. The same payment QR is included in the booking-confirmation PDF.

## Operations module (v2)

Open the grid icon in the app bar for:

- Date-range vehicle availability and conflict checking
- Pickup and return inspections with odometer, fuel, photos/videos, customer signature, and PDF reports
- Customer driving licence, Aadhaar/ID, PAN, and licence-expiry tracking
- Expense recording and income/expense/profit reporting

Each booking menu now also includes:

- Invoice or payment-receipt PDF sharing
- Return calculation for extra kilometres, late hours, fuel, damage, and washing charges
- Full booking status workflow from enquiry through completion or cancellation
- Eight prepared WhatsApp message templates

## Phone contacts

On the **Customers** screen, tap **Select from Phone Contacts**. Android opens its native contact picker and fills in the selected contact's name and first phone number. The app only receives the contact selected by the user.

## Signed rental agreements

1. Open **Bookings** and tap the menu on a booking.
2. Select **Create agreement**.
3. Confirm the customer and vehicle details and ask the customer to sign.
4. Tap **Create Signed Agreement**.
5. Use **Download Agreement** or **Share via WhatsApp**.

The PDF is saved in the app's private agreements folder and its path is stored in the booking row of the Excel database. The download button opens Android's save-file screen. The WhatsApp button attaches the PDF to Android's share sheet; choose WhatsApp there.

The agreement includes the business's mileage, late-return, security-deposit, advance-payment, speed-limit, vehicle-damage, alcohol, toll, fuel, Mumbai-Pune Expressway, and cleanliness terms.

## Codemagic
The build workflow installs Android SDK 36, creates the Android wrapper, and explicitly sets compileSdk to 36 before building the release APK.

Upload this project to GitHub with `pubspec.yaml` and `codemagic.yaml` at the repository root, then run the `android-release` workflow in Codemagic.

The v2.0.2 GitHub workflow uses the Android SDK already installed on the hosted runner. It does not call `android-actions/setup-android`, which avoids that action's obsolete `Failed to find package 'tools'` error. Both workflows accept Android SDK licences before installing API 36 and do not request the optional exact `build-tools;36.0.0` package.

Version 2.0.3 updates `file_picker` to `10.3.3`, which follows Flutter's configured Android compile SDK and remains compatible with the project's existing file-selection and save-file calls.

Version 2.0.4 uses the GitHub Runner's confirmed absolute SDK Manager path, `$ANDROID_SDK_ROOT/cmdline-tools/16.0/bin/sdkmanager`, because that executable is installed but is not included in the runner's command `PATH`.

Version 2.0.5 removes all manual `sdkmanager` commands from both GitHub Actions and Codemagic. The generated Android project now uses `flutter.compileSdkVersion`, allowing the installed stable Flutter toolchain and `file_picker 10.3.3` to select the compatible compile SDK automatically. This bypasses the repeatedly failing SDK Manager installation completely.
