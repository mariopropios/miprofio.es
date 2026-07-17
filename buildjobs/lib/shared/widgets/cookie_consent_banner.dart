import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/legal/cookie_consent_store.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';

/// Banner de consentimiento (necesarias vs opcionales).
class CookieConsentHost extends StatefulWidget {
  const CookieConsentHost({super.key, required this.child});

  final Widget child;

  @override
  State<CookieConsentHost> createState() => _CookieConsentHostState();
}

class _CookieConsentHostState extends State<CookieConsentHost> {
  CookieConsentPrefs _prefs = CookieConsentPrefs.undecided;
  bool _ready = false;
  bool _showPreferences = false;
  bool _analytics = false;
  bool _marketing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prefs = CookieConsentStore.read();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _analytics = prefs.analytics;
        _marketing = prefs.marketing;
        _ready = true;
      });
    });
  }

  Future<void> _save(CookieConsentPrefs prefs) async {
    await CookieConsentStore.write(prefs);
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _showPreferences = false;
      _analytics = prefs.analytics;
      _marketing = prefs.marketing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showBanner = _ready && !_prefs.decided;

    return Stack(
      children: [
        widget.child,
        if (showBanner)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _CookieBannerCard(
                showPreferences: _showPreferences,
                analytics: _analytics,
                marketing: _marketing,
                onToggleAnalytics: (v) => setState(() => _analytics = v),
                onToggleMarketing: (v) => setState(() => _marketing = v),
                onAcceptAll: () => _save(CookieConsentPrefs.acceptedAll),
                onRejectOptional: () =>
                    _save(CookieConsentPrefs.rejectedOptional),
                onConfigure: () => setState(() => _showPreferences = true),
                onSavePreferences: () => _save(
                      CookieConsentPrefs(
                        decided: true,
                        analytics: _analytics,
                        marketing: _marketing,
                      ),
                    ),
                onOpenCookies: () => context.push(AppRoutes.cookies),
                onOpenPrivacy: () => context.push(AppRoutes.privacy),
              ),
            ),
          ),
      ],
    );
  }
}

class _CookieBannerCard extends StatelessWidget {
  const _CookieBannerCard({
    required this.showPreferences,
    required this.analytics,
    required this.marketing,
    required this.onToggleAnalytics,
    required this.onToggleMarketing,
    required this.onAcceptAll,
    required this.onRejectOptional,
    required this.onConfigure,
    required this.onSavePreferences,
    required this.onOpenCookies,
    required this.onOpenPrivacy,
  });

  final bool showPreferences;
  final bool analytics;
  final bool marketing;
  final ValueChanged<bool> onToggleAnalytics;
  final ValueChanged<bool> onToggleMarketing;
  final VoidCallback onAcceptAll;
  final VoidCallback onRejectOptional;
  final VoidCallback onConfigure;
  final VoidCallback onSavePreferences;
  final VoidCallback onOpenCookies;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.cookie_outlined,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Cookies y privacidad',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text.rich(
                    TextSpan(
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                            height: 1.45,
                          ),
                      children: [
                        const TextSpan(
                          text:
                              'Usamos tecnologías necesarias para el servicio (sesión, seguridad, PWA). '
                              'Las opcionales (analytics/marketing) están opcionales y hoy no cargamos publicidad. ',
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: onOpenCookies,
                            child: const Text(
                              'Política de cookies',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: ' · '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: onOpenPrivacy,
                            child: const Text(
                              'Privacidad',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showPreferences) ...[
                    const SizedBox(height: 12),
                    _PrefTile(
                      title: 'Necesarias',
                      subtitle: 'Sesión, seguridad y preferencias esenciales',
                      value: true,
                      enabled: false,
                      onChanged: null,
                    ),
                    _PrefTile(
                      title: 'Analytics',
                      subtitle: 'Métricas opcionales (si se activan en el futuro)',
                      value: analytics,
                      enabled: true,
                      onChanged: onToggleAnalytics,
                    ),
                    _PrefTile(
                      title: 'Marketing',
                      subtitle: 'Comunicación comercial opcional',
                      value: marketing,
                      enabled: true,
                      onChanged: onToggleMarketing,
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (!showPreferences) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onRejectOptional,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textPrimary,
                              side: const BorderSide(color: AppTheme.divider),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Rechazar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onConfigure,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side: BorderSide(
                                color: AppTheme.primary.withValues(alpha: 0.5),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Configurar'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onAcceptAll,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Aceptar',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onSavePreferences,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Guardar preferencias',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onRejectOptional,
                      child: const Text('Solo necesarias'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          height: 1.3,
        ),
      ),
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: AppTheme.primary,
    );
  }
}
