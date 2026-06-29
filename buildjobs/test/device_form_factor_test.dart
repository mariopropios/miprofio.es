import 'package:buildjobs/core/utils/device_form_factor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child, Size size) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(home: child),
    );
  }

  testWidgets('iPhone no enmarca contenido', (tester) async {
    await tester.pumpWidget(
      wrap(
        const TabletAdaptiveFrame(child: Text('app')),
        const Size(390, 844),
      ),
    );

    expect(find.text('app'), findsOneWidget);
    expect(
      DeviceFormFactor.shouldFrameTabletContent(
        tester.element(find.text('app')),
      ),
      isFalse,
    );
  });
}
