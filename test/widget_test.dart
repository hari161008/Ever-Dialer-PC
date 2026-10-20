import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ever_dialer_pc/main.dart';
import 'package:ever_dialer_pc/services/bluetooth_service.dart';

void main() {
  testWidgets('EverDialerApp defaults to OFF on clean startup', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final mockService = BluetoothService(
      autoStartTimer: false,
      autoRefresh: false,
      prefs: prefs,
    );

    await tester.pumpWidget(EverDialerApp(bluetoothService: mockService, prefs: prefs));
    await tester.pump();

    expect(find.text('Ever Dialer PC'), findsWidgets);
    expect(find.text('Bluetooth Connection'), findsOneWidget);
    expect(find.text('Media Speaker Mode Disabled'), findsOneWidget);
    expect(mockService.state.speakerModeEnabled, false);

    mockService.dispose();
  });

  testWidgets('EverDialerApp restores ON state when persisted', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'speaker_mode_enabled': true});
    final prefs = await SharedPreferences.getInstance();

    final mockService = BluetoothService(
      autoStartTimer: false,
      autoRefresh: false,
      prefs: prefs,
    );

    await tester.pumpWidget(EverDialerApp(bluetoothService: mockService, prefs: prefs));
    await tester.pump();

    expect(find.text('Bluetooth Connection'), findsOneWidget);
    expect(find.text('Media Speaker Mode Disabled'), findsNothing);
    expect(mockService.state.speakerModeEnabled, true);

    mockService.dispose();
  });
}
