import 'package:buildjobs/core/utils/device_form_factor.dart';
import 'package:buildjobs/shared/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child, Size size) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(home: child),
    );
  }

  testWidgets('iPhone usa ancho completo de contenido', (tester) async {
    await tester.pumpWidget(
      wrap(const Text('app'), const Size(390, 844)),
    );

    final context = tester.element(find.text('app'));
    expect(DeviceFormFactor.contentMaxWidth(context), double.infinity);
    expect(ResponsiveLayout.isDesktop(context), isFalse);
  });

  testWidgets('viewport iPad Pro no usa shell escritorio', (tester) async {
    await tester.pumpWidget(
      wrap(const SizedBox.shrink(), const Size(1024, 1366)),
    );

    final context = tester.element(find.byType(SizedBox));
    expect(ResponsiveLayout.isDesktop(context), isFalse);
    expect(DeviceFormFactor.contentMaxWidth(context), double.infinity);
  });
}
