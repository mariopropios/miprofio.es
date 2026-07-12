import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';

enum ChatAttachmentSource { gallery, camera, file }

typedef ChatAttachmentPickCallback = Future<XFile?> Function(
  ChatAttachmentSource source,
);

/// Menú de adjuntos estilo WhatsApp.
abstract final class ChatAttachmentMenu {
  static Future<XFile?> show(
    BuildContext context, {
    required ChatAttachmentPickCallback onPick,
  }) async {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final pickFuture = await showGeneralDialog<Future<XFile?>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar menú de adjuntos',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (context, animation, _, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: child,
        );
      },
      pageBuilder: (context, animation, _) {
        return SafeArea(
          child: Stack(
            children: [
              Positioned(
                right: 10,
                bottom: bottomInset + 58,
                child: FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: _MenuCard(onPick: onPick),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (pickFuture == null) return null;
    return pickFuture;
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.onPick});

  final ChatAttachmentPickCallback onPick;

  static const _bg = Color(0xFF2A3942);
  static const _text = Color(0xFFE9EDEF);
  static const _icon = Color(0xFF8696A0);

  void _select(BuildContext context, ChatAttachmentSource source) {
    // Lanzar el selector en el mismo gesto del tap (clave en iOS/Safari).
    final future = onPick(source);
    Navigator.pop(context, future);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 248,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MenuItem(
                icon: Icons.photo_library_outlined,
                label: 'Fototeca',
                onTap: () => _select(context, ChatAttachmentSource.gallery),
              ),
              const Divider(height: 1, thickness: 0.5, color: Color(0xFF3B4A54)),
              _MenuItem(
                icon: Icons.photo_camera_outlined,
                label: 'Hacer foto',
                onTap: () => _select(context, ChatAttachmentSource.camera),
              ),
              const Divider(height: 1, thickness: 0.5, color: Color(0xFF3B4A54)),
              _MenuItem(
                icon: Icons.folder_open_outlined,
                label: 'Seleccionar archivo',
                onTap: () => _select(context, ChatAttachmentSource.file),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onTap(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: _MenuCard._icon, size: 22),
            const SizedBox(width: 18),
            Text(
              label,
              style: const TextStyle(
                color: _MenuCard._text,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
