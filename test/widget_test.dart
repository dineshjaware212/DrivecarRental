import 'package:driverent_manager/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DriveRent root widget is available', () {
    const app = DriveRentApp();
    expect(app, isA<DriveRentApp>());
  });
}
