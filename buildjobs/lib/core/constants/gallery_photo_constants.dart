/// Proporción y tamaños de las fotos de trabajos en perfil y tarjetas.
abstract final class GalleryPhotoConstants {
  /// Miniatura en la franja de galería del perfil.
  static const thumbWidth = 140.0;
  static const thumbHeight = 120.0;

  /// Relación ancho/alto del recorte (horizontal, como en el perfil).
  static const aspectRatio = thumbWidth / thumbHeight;

  /// Vista previa al subir (misma proporción que en perfil).
  static const previewHeight = 88.0;
  static const previewWidth = previewHeight * aspectRatio;

  /// Texto + padding bajo la foto en [CompanyCard].
  static const cardInfoBandHeight = 148.0;

  /// Altura total estimada de una tarjeta para un ancho dado.
  static double estimatedCardHeight(double cardWidth) =>
      cardWidth / aspectRatio + cardInfoBandHeight;

  /// [childAspectRatio] de GridView para tarjetas con este ancho de celda.
  static double gridChildAspectRatio(double cardWidth) =>
      cardWidth / estimatedCardHeight(cardWidth);

  /// Ratio seguro para [GridView] según ancho disponible y columnas.
  static double gridChildAspectRatioFor({
    required double gridWidth,
    required int crossAxisCount,
    double crossAxisSpacing = 16,
    double heightSlack = 16,
  }) {
    if (gridWidth <= 0 || crossAxisCount < 1) return 0.72;
    final cardWidth =
        (gridWidth - crossAxisSpacing * (crossAxisCount - 1)) / crossAxisCount;
    final cardHeight = estimatedCardHeight(cardWidth) + heightSlack;
    return cardWidth / cardHeight;
  }

  /// Ancho máximo de tarjeta en el tambor ([CompanyCardDeck]).
  /// Por debajo de ~680 px de marco en iPad; evita ítems >700 px que colgaban web.
  static const deckMaxCardWidth = 600.0;

  /// Por debajo de este ancho se usa el 100 % (teléfono).
  static const deckPhoneMaxWidth = 420.0;

  /// Ancho efectivo: móvil a ancho completo; tablet casi todo el hueco (7:6).
  static double deckCardWidth(double availableWidth) {
    if (availableWidth <= deckPhoneMaxWidth) return availableWidth;
    final inset = availableWidth > 520 ? 16.0 : 8.0;
    return (availableWidth - inset).clamp(deckPhoneMaxWidth, deckMaxCardWidth);
  }

  /// Padding vertical extra por ítem en [CompanyCardDeck].
  static const deckItemVerticalPadding = 12.0;

  /// Altura del viewport del tambor (Inicio y Buscar comparten esta fórmula).
  static double deckViewportHeight(double screenHeight) {
    return (screenHeight * 0.78).clamp(440.0, 760.0);
  }

  /// [itemExtent] del tambor para un ancho de columna dado.
  static double deckItemExtent(double columnWidth) {
    const horizontalPadding = 8.0;
    final availableWidth = columnWidth - horizontalPadding;
    final cardWidth = deckCardWidth(availableWidth);
    return estimatedCardHeight(cardWidth) + deckItemVerticalPadding;
  }
}
