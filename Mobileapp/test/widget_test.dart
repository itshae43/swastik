import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swastik_mobile_app/main.dart';
import 'package:swastik_mobile_app/features/device_info/domain/entities/device_info.dart';
import 'package:swastik_mobile_app/features/device_info/presentation/providers/device_info_provider.dart';
import 'package:swastik_mobile_app/features/device_info/presentation/providers/verification_provider.dart';
import 'package:swastik_mobile_app/features/device_info/domain/repositories/verification_repository.dart';

// Mock Repository for testing verification flows
class MockVerificationRepository implements VerificationRepository {
  final bool shouldSucceed;
  final String? customMessage;

  MockVerificationRepository({required this.shouldSucceed, this.customMessage});

  @override
  Future<Map<String, dynamic>> verifyDevice(DeviceInfo deviceInfo) async {
    if (shouldSucceed) {
      return {'verified': true};
    } else {
      return {'verified': false, 'message': customMessage ?? 'Please contact to admin'};
    }
  }
}

void main() {
  testWidgets('Verification screen displays correct elements and switches tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title and Tabs
    expect(find.text("Let's Get Started!"), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Other User'), findsOneWidget);
    expect(find.text('Click to Verify'), findsOneWidget);
  });

  testWidgets('Verification success navigates to greeting page with device info details', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Override Device Info
          deviceInfoFutureProvider.overrideWith((ref) async {
            return const DeviceInfo(
              brand: 'google',
              model: 'Pixel Tablet',
              device: 'PixelTabletDevice',
              id: 'PixelTabletID',
              androidId: 'd0b41708a4f50758',
            );
          }),
          // Override Verification Repo to succeed
          verificationRepositoryProvider.overrideWithValue(
            MockVerificationRepository(shouldSucceed: true),
          ),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Tap verify button
    await tester.tap(find.text('Click to Verify'));
    
    // Pump frames to resolve async verification call
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Verify GreetingPage (Hello World / Device Info) is now visible
    expect(find.text('SWASTIK'), findsOneWidget);
    expect(find.text('Clean Architecture • Riverpod'), findsOneWidget);
    expect(find.text('DEVICE INFO'), findsOneWidget);
    expect(find.text('google - Pixel Tablet'), findsOneWidget);
    expect(find.text('PixelTabletDevice'), findsOneWidget);
    expect(find.text('PixelTabletID'), findsOneWidget);
    expect(find.text('d0b41708a4f50758'), findsOneWidget);
  });

  testWidgets('Verification failure displays please contact to admin message', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Override Device Info
          deviceInfoFutureProvider.overrideWith((ref) async {
            return const DeviceInfo(
              brand: 'apple',
              model: 'iPhone',
              device: 'iPhoneDevice',
              id: 'iPhoneID',
              androidId: '12345',
            );
          }),
          // Override Verification Repo to fail
          verificationRepositoryProvider.overrideWithValue(
            MockVerificationRepository(
              shouldSucceed: false,
              customMessage: 'Please contact to admin',
            ),
          ),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Tap verify button
    await tester.tap(find.text('Click to Verify'));
    
    // Pump frames to resolve async verification call
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Verify error is displayed on screen
    expect(find.text('Please contact to admin'), findsOneWidget);
  });
}
