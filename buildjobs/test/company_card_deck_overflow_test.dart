import 'package:buildjobs/core/constants/gallery_photo_constants.dart';
import 'package:buildjobs/core/theme/app_theme.dart';
import 'package:buildjobs/shared/models/professional.dart';
import 'package:buildjobs/shared/widgets/company_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Professional _worstCasePro() {
  return const Professional(
    id: 'test-cubierta',
    name: 'Protegemos tu Cubierta',
    profession:
        'Fontanero, Impermeabilizador, Techador, Albañil, Pintor, Cerrajero',
    city: 'Segovia, Madrid, Norte de España y península',
    rating: 5,
    reviewCount: 2,
    address: 'Segovia',
    serviceRadiusKm: 150,
    savedCount: 1,
  );
}

Professional _simplePro() {
  return const Professional(
    id: 'test-simple',
    name: 'ODR montajes',
    profession: 'Fontanero',
    city: 'Madrid',
    rating: 4.5,
    reviewCount: 3,
    address: 'Madrid',
    serviceRadiusKm: 0,
    savedCount: 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<String>> pumpDenseCard(
    WidgetTester tester,
    Professional company, {
    double width = 336,
  }) async {
    final overflows = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (details) {
      final s = details.exceptionAsString();
      if (s.contains('OVERFLOWED') || s.contains('overflowed')) {
        overflows.add(s);
      }
      old?.call(details);
    };

    final height =
        GalleryPhotoConstants.deckEstimatedCardHeight(width);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: CompanyCard(
                company: company,
                dense: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    FlutterError.onError = old;
    return overflows;
  }

  testWidgets('dense card peor caso (radio + chips + ciudad) sin overflow',
      (tester) async {
    final overflows = await pumpDenseCard(tester, _worstCasePro());
    expect(overflows, isEmpty, reason: overflows.join('\n'));
  });

  testWidgets('dense card simple sin overflow', (tester) async {
    final overflows = await pumpDenseCard(tester, _simplePro());
    expect(overflows, isEmpty, reason: overflows.join('\n'));
  });

  testWidgets('ítem del tambor (padding vertical + itemExtent) peor caso',
      (tester) async {
    final overflows = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (details) {
      final s = details.exceptionAsString();
      if (s.contains('OVERFLOWED') || s.contains('overflowed')) {
        overflows.add(s);
      }
      old?.call(details);
    };

    const laneWidth = 390.0;
    const horizontalPadding = 8.0;
    final availableWidth = laneWidth - horizontalPadding;
    final cardWidth =
        GalleryPhotoConstants.deckCardWidth(availableWidth);
    final cardHeight =
        GalleryPhotoConstants.deckEstimatedCardHeight(cardWidth);
    final itemExtent = GalleryPhotoConstants.deckItemExtent(laneWidth);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SizedBox(
            width: cardWidth,
            height: itemExtent,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: CompanyCard(
                  company: _worstCasePro(),
                  dense: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    FlutterError.onError = old;
    expect(overflows, isEmpty, reason: overflows.join('\n'));
  });

  testWidgets('dense card con textScaler 1.3 sin overflow', (tester) async {
    final overflows = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (details) {
      final s = details.exceptionAsString();
      if (s.contains('OVERFLOWED') || s.contains('overflowed')) {
        overflows.add(s);
      }
      old?.call(details);
    };

    const width = 336.0;
    final height =
        GalleryPhotoConstants.deckEstimatedCardHeight(width);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(1.3),
        ),
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                height: height,
                child: CompanyCard(
                  company: _worstCasePro(),
                  dense: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    FlutterError.onError = old;
    expect(overflows, isEmpty, reason: overflows.join('\n'));
  });
}
