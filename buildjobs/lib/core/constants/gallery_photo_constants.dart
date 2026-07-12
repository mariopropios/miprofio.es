import 'package:flutter/material.dart';

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

  /// NavigationBar inferior del shell móvil (Material 3).
  static const deckNavBarHeight = 80.0;

  /// Bloque título + separación antes del deck (Inicio).
  static const deckHomeTitleBlockHeight = 68.0;

  /// Barra fija de chips activos en Buscar (Fontanero, ciudad, etc.).
  static const deckSearchPinnedChipsHeight = 56.0;

  static const deckBottomSafety = 8.0;

  /// Hueco visible bajo la tarjeta del deck (sobre el bottom nav).
  static const deckBottomBreathingRoom = 40.0;

  /// Scroll extra al final del [CustomScrollView] (overscroll útil).
  static const deckScrollBottomSlack = 32.0;

  /// Cola scrollable bajo el deck (hueco + overscroll).
  static double get deckScrollTailHeight =>
      deckBottomBreathingRoom + deckScrollBottomSlack;

  /// Scroll de la página (filtros / cabecera) cuando el gesto empieza fuera
  /// de la tarjeta del tambor.
  static const mobileOuterScrollPhysics = AlwaysScrollableScrollPhysics(
    parent: BouncingScrollPhysics(
      decelerationRate: ScrollDecelerationRate.fast,
    ),
  );

  /// Altura del deck según el viewport real del body (sin restar nav dos veces).
  static double deckContentHeightForViewport(
    double viewportHeight, {
    required double pinnedHeaderHeight,
    bool isTablet = false,
  }) {
    const minCap = 240.0;
    final maxCap = isTablet ? 620.0 : 560.0;
    final height =
        viewportHeight - pinnedHeaderHeight - deckScrollTailHeight;
    return height.clamp(minCap, maxCap);
  }

  /// Altura del deck en un sliver (body − cabecera fija − cola inferior).
  static double deckContentHeight(
    BuildContext context, {
    required double pinnedHeaderHeight,
    bool isTablet = false,
  }) {
    return deckContentHeightForViewport(
      mobileShellBodyHeight(context),
      pinnedHeaderHeight: pinnedHeaderHeight,
      isTablet: isTablet,
    );
  }

  /// @deprecated Usar [deckContentHeight].
  static double deckHeightInRemaining(double maxHeight) {
    final height = maxHeight - deckBottomBreathingRoom;
    return height > 0 ? height : maxHeight;
  }

  /// Altura útil del body entre AppBar y barra inferior (shell móvil).
  static double mobileShellBodyHeight(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.size.height -
        mq.padding.top -
        kToolbarHeight -
        deckNavBarHeight -
        mq.padding.bottom;
  }

  /// Altura del viewport cuando el deck llena el espacio bajo la cabecera fija.
  static double deckViewportHeightAnchored(
    BuildContext context, {
    required double headerChrome,
    bool isTablet = false,
  }) {
    const minCap = 280.0;
    final maxCap = isTablet ? 640.0 : 580.0;
    final height = mobileShellBodyHeight(context) -
        headerChrome -
        deckBottomSafety;
    return height.clamp(minCap, maxCap);
  }

  /// Inicio: referencia de altura del título anclado (usado por [PinnedHeaderDelegate]).
  static double deckViewportHeightForHome(
    BuildContext context, {
    bool isTablet = false,
  }) {
    return deckViewportHeightAnchored(
      context,
      headerChrome: deckHomeTitleBlockHeight,
      isTablet: isTablet,
    );
  }

  /// Buscar: referencia si se calcula altura sin [SliverFillRemaining].
  static double deckViewportHeightForSearch(
    BuildContext context, {
    required double filtersPanelHeight,
    bool isTablet = false,
  }) {
    return deckViewportHeightAnchored(
      context,
      headerChrome: filtersPanelHeight,
      isTablet: isTablet,
    );
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
