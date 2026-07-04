import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Evita la selección accidental de texto y el highlight azul del navegador
/// al pulsar controles táctiles en Flutter web.
class WebTapGuard extends StatelessWidget {
  const WebTapGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return SelectionContainer.disabled(child: child);
  }
}
