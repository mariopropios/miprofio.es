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

  /// Texto + padding bajo la foto en [CompanyCard] (grid / desktop).
  static const cardInfoBandHeight = 148.0;

  /// Banda de info en el tambor ([CompanyCard.dense]); alineada al layout real.
  static const deckCardInfoBandHeight = 136.0;

  /// Padding vertical del ítem en [CompanyCardDeck] (6 + 6).
  static const deckWheelItemPadding = 12.0;

  /// Altura total estimada de una tarjeta para un ancho dado.
  static double estimatedCardHeight(double cardWidth) =>
      cardWidth / aspectRatio + cardInfoBandHeight;

  /// Altura de tarjeta en [CompanyCardDeck] (un poco más baja que en grid).
  static double deckEstimatedCardHeight(double cardWidth) =>
      cardWidth / aspectRatio + deckCardInfoBandHeight;

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
  static const deckMaxCardWidth = 540.0;

  /// Por debajo de este ancho se usa factor de escala (teléfono).
  static const deckPhoneMaxWidth = 420.0;

  /// Escala horizontal en móvil para que la tarjeta quepa entera al hacer scroll.
  static const deckPhoneWidthFactor = 0.88;

  /// Ancho efectivo: móvil algo más estrecho; tablet con tope reducido.
  static double deckCardWidth(double availableWidth) {
    if (availableWidth <= deckPhoneMaxWidth) {
      return availableWidth * deckPhoneWidthFactor;
    }
    final inset = availableWidth > 520 ? 24.0 : 12.0;
    return (availableWidth - inset).clamp(deckPhoneMaxWidth, deckMaxCardWidth);
  }

  /// Padding vertical extra por ítem en [CompanyCardDeck].
  static const deckItemVerticalPadding = 8.0;

  /// Espacio que debe quedar visible del contenido superior (filtros, título)
  /// cuando el usuario llega al deck en móvil/tablet.
  static const deckPeekReserve = 100.0;

  /// AppBar + barra inferior + margen (shell móvil aproximado).
  static const deckShellChrome = 156.0;

  /// Altura del viewport del tambor (Inicio y Buscar comparten esta fórmula).
  ///
  /// Más baja que antes en móvil/tablet para dejar "peek" del contenido
  /// superior y facilitar deslizar la página hacia arriba fuera del tambor.
  static double deckViewportHeight(
    double screenHeight, {
    bool isTablet = false,
  }) {
    const minCap = 300.0;
    final maxCap = isTablet ? 520.0 : 460.0;
    final fraction = isTablet ? 0.58 : 0.52;

    final byFraction = screenHeight * fraction;
    final peekCap = (screenHeight - deckShellChrome - deckPeekReserve)
        .clamp(minCap, maxCap);

    return byFraction.clamp(minCap, maxCap).clamp(minCap, peekCap);
  }

  /// [itemExtent] del tambor para un ancho de columna dado.
  static double deckItemExtent(double columnWidth) {
    const horizontalPadding = 8.0;
    final availableWidth = columnWidth - horizontalPadding;
    final cardWidth = deckCardWidth(availableWidth);
    return deckEstimatedCardHeight(cardWidth) +
        deckWheelItemPadding +
        deckItemVerticalPadding;
  }
}
