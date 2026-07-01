import 'package:flutter/material.dart';

import '../../../../core/services/geo_permission_helper.dart';
import '../../../../core/services/geo_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Bottom sheet para seleccionar o autodetectar ciudad.
class LocationFilterSheet extends StatefulWidget {
  const LocationFilterSheet({super.key, this.current});

  final String? current;

  /// Abre el sheet y devuelve la ciudad elegida (null = sin filtro).
  static Future<String?> show(BuildContext context, {String? current}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationFilterSheet(current: current),
    );
  }

  @override
  State<LocationFilterSheet> createState() => _LocationFilterSheetState();
}

class _LocationFilterSheetState extends State<LocationFilterSheet> {
  final _controller = TextEditingController();
  bool _detecting = false;
  String? _geoError;

  static const _popular = [
    'Madrid', 'Barcelona', 'Valencia', 'Sevilla', 'Bilbao',
    'Málaga', 'Zaragoza', 'Murcia', 'Alicante', 'Palma de Mallorca',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.current != null) _controller.text = widget.current!;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() {
      _detecting = true;
      _geoError = null;
    });
    try {
      final city = await GeoService.detectCity();
      if (mounted) {
        _controller.text = city;
        setState(() {});
      }
    } on GeoServiceException catch (e) {
      if (mounted) {
        setState(() => _geoError = e.message);
        await GeoPermissionHelper.handleException(context, e);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('timeout') || e.toString().contains('TimeoutException')
            ? 'Tiempo agotado. Comprueba que el navegador tiene permiso de ubicación o escribe la ciudad.'
            : 'No se pudo detectar la ubicación. Escribe la ciudad manualmente.';
        setState(() => _geoError = msg);
      }
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        maxWidth: isMobile ? double.infinity : 440,
      ),
      margin: isMobile
          ? null
          : EdgeInsets.symmetric(
              horizontal:
                  (MediaQuery.sizeOf(context).width - 440) / 2,
              vertical: 48,
            ),
      decoration: const BoxDecoration(
        color: AppTheme.scaffoldBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Pill
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Dónde buscas?',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Campo de texto ────────────────────────────────────
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style:
                      const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Ciudad o municipio...',
                    hintStyle: const TextStyle(
                        color: AppTheme.textSecondary),
                    prefixIcon: const Icon(Icons.location_on_outlined,
                        color: AppTheme.textSecondary),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                color: AppTheme.textSecondary),
                            onPressed: () {
                              _controller.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primary, width: 1.5),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) {
                      Navigator.pop(context, v.trim());
                    }
                  },
                ),
                const SizedBox(height: 10),

                // ── Botón detectar ubicación ──────────────────────────
                SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _detecting ? null : _detectLocation,
                      icon: _detecting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded,
                              size: 18),
                      label: Text(_detecting
                          ? 'Detectando...'
                          : 'Usar mi ubicación actual'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                if (_geoError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _geoError!,
                    style: const TextStyle(
                        color: Colors.red, fontSize: 12),
                  ),
                ],

                const SizedBox(height: 16),

                // ── Ciudades populares ────────────────────────────────
                const Text(
                  'Ciudades populares',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _popular.map((city) {
                    final selected = _controller.text
                            .trim()
                            .toLowerCase() ==
                        city.toLowerCase();
                    return GestureDetector(
                      onTap: () => Navigator.pop(context, city),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? AppTheme.primary
                                : const Color(0xFF3A444D),
                          ),
                        ),
                        child: Text(
                          city,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // ── Botones de acción ─────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, ''),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(color: AppTheme.divider),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Quitar filtro'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _controller.text.trim().isEmpty
                            ? null
                            : () => Navigator.pop(
                                context, _controller.text.trim()),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Aplicar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
