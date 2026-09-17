# GoCar Rental Services v2.3

Android-only car and two-wheeler rental manager with a local XLSX database.

## Automatic booking totals and payment balances

Bookings use customer and vehicle selectors. Every booking has an editable daily rent, initially copied from the vehicle's default rate. The total updates automatically from the rental period and this customer-specific rate. The Payments screen shows the booking total, payments already received, and the remaining balance.

The app also prevents overlapping bookings for the same car, updates each booking to **Partially Paid** or **Paid**, displays collected and outstanding totals on the dashboard, provides a payment-method selector, and requires the customer to review and accept the terms before signing.

## Vehicle catalog and booking confirmation

Add cars or two-wheelers, upload a photo from each vehicle's menu, and share a PDF catalog of currently available vehicles through WhatsApp.

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

On the **Customers** screen, tap **Select Contact & Add Customer**. After contacts permission is granted, Android opens its native picker. The app reads only the selected contact's name and first phone number and immediately creates the customer.

## Booking documents and invoices

Each booking menu includes **Customer documents**, which opens the selected customer's licence, Aadhaar/ID, PAN, and licence-expiry records for upload or replacement. **Share invoice / receipt** generates a detailed PDF with invoice number and date, customer and vehicle details, rental period, booking-specific daily rent, security deposit, payment history, amount received, and balance due.

Dashboard summary cards are clickable and switch directly to Vehicles, Customers, Bookings, Payments, or Service.

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

## One-click APK building

This version follows the supplied working reference project. It never invokes `sdkmanager`. After stable Flutter creates the Android wrapper, the workflows set the generated app module to `compileSdk 36` and build the release APK.

- **GitHub:** Actions → Build GoCar Rental Services APK → Run workflow → download `GoCar-Rental-Services-APK` from Artifacts.
- **Codemagic:** Run the `android-release` workflow and download `app-release.apk` from Artifacts.
- **Windows PC:** Double-click `build_apk.bat` after installing Flutter and Android SDK 36.
- **macOS/Linux:** Run `chmod +x build_apk.sh`, then `./build_apk.sh`.

The generated APK location is `build/app/outputs/flutter-apk/app-release.apk`. The project uses `file_picker 10.3.3`.

Version 2.1.1 resolves Flutter analysis errors by hiding Excel's conflicting `Border` type and including a widget test that uses the correct `DriveRentApp` root widget instead of Flutter's default `MyApp` placeholder.

Version 2.3.0 adds cars and two-wheelers throughout the app, customer-specific booking rates, clickable dashboard navigation, booking-linked customer documents, contact-to-customer creation, GoCar Rental Services branding, and detailed invoice/receipt PDFs.

Version 2.4.0 adds pickup and return times, booking date/time editing, searchable customer selection, coloured booking statuses, direct customer calling and payment navigation, cancellation-aware earnings, detailed upcoming returns, date-filtered vehicle availability, WhatsApp catalog details, and individual vehicle-photo sharing.

Version 2.4.1 fixes the catalog syntax error reported by Flutter analysis and updates all dropdown form fields to the current `initialValue` API. It also resolves the reported control-flow brace and unnecessary-import analyzer notices.

Version 2.5.0 adds booking-list filters for customer/booking ID and status, plus post-booking pickup/drop odometer readings, fuel levels, and odometer photos. Extra kilometres are calculated automatically from the readings after the included 350 km per rental day. Ertiga is charged at INR 7 per extra kilometre and every other vehicle at INR 5. Fuel shortage is calculated automatically as `(pickup fuel % - drop fuel %) × 0.5 × INR 112` and included in return charges.
