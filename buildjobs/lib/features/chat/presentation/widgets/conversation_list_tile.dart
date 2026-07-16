import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/message.dart';

/// Fila de conversación con swipe (izq.) → Archivar / Eliminar,
/// long-press → menú, y botón ⋮ en escritorio.
class ConversationListTile extends StatefulWidget {
  const ConversationListTile({
    super.key,
    required this.conversation,
    required this.onOpen,
    required this.onArchive,
    required this.onDelete,
    this.archiveLabel = 'Archivar',
    this.showArchiveAction = true,
  });

  final Conversation conversation;
  final VoidCallback onOpen;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final String archiveLabel;
  final bool showArchiveAction;

  @override
  State<ConversationListTile> createState() => _ConversationListTileState();
}

class _ConversationListTileState extends State<ConversationListTile> {
  static const double _actionWidth = 76;
  double _offset = 0;
  bool _hovering = false;

  double get _maxReveal {
    final n = widget.showArchiveAction ? 2 : 1;
    return _actionWidth * n;
  }

  void _close() {
    if (_offset == 0) return;
    setState(() => _offset = 0);
  }

  void _snapOpen() {
    setState(() => _offset = -_maxReveal);
  }

  Future<void> _showActionsSheet() async {
    _close();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.surfaceElevated,
                  backgroundImage: widget.conversation.peerPhoto != null &&
                          widget.conversation.peerPhoto!.isNotEmpty
                      ? NetworkImage(widget.conversation.peerPhoto!)
                      : null,
                  child: widget.conversation.peerPhoto == null ||
                          widget.conversation.peerPhoto!.isEmpty
                      ? Text(
                          widget.conversation.peerName.isNotEmpty
                              ? widget.conversation.peerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  widget.conversation.peerName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 1, color: AppTheme.divider),
              if (widget.showArchiveAction)
                ListTile(
                  leading: const Icon(Icons.archive_outlined,
                      color: AppTheme.primary),
                  title: Text(
                    widget.archiveLabel,
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onArchive();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFFF453A)),
                title: const Text(
                  'Eliminar',
                  style: TextStyle(color: Color(0xFFFF453A)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onDelete();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onLongPress: _showActionsSheet,
        onHorizontalDragUpdate: (details) {
          final next = (_offset + details.delta.dx).clamp(-_maxReveal, 0.0);
          if (next != _offset) setState(() => _offset = next);
        },
        onHorizontalDragEnd: (details) {
          final vx = details.primaryVelocity ?? 0;
          if (vx < -400 || _offset < -_maxReveal * 0.45) {
            _snapOpen();
          } else {
            _close();
          }
        },
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.showArchiveAction)
                    _ActionButton(
                      width: _actionWidth,
                      color: const Color(0xFF3B82F6),
                      icon: Icons.archive_outlined,
                      label: widget.archiveLabel,
                      onTap: () {
                        _close();
                        widget.onArchive();
                      },
                    ),
                  _ActionButton(
                    width: _actionWidth,
                    color: const Color(0xFFFF453A),
                    icon: Icons.delete_outline,
                    label: 'Eliminar',
                    onTap: () {
                      _close();
                      widget.onDelete();
                    },
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: Offset(_offset, 0),
              child: Material(
                color: AppTheme.scaffoldBackground,
                child: InkWell(
                  onTap: () {
                    if (_offset != 0) {
                      _close();
                      return;
                    }
                    widget.onOpen();
                  },
                  child: _ConversationRowContent(
                    conversation: widget.conversation,
                    trailing: wide || _hovering
                        ? IconButton(
                            onPressed: _showActionsSheet,
                            icon: const Icon(
                              Icons.more_vert,
                              color: AppTheme.textSecondary,
                              size: 20,
                            ),
                            tooltip: 'Opciones',
                            visualDensity: VisualDensity.compact,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.width,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final double width;
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationRowContent extends StatelessWidget {
  const _ConversationRowContent({
    required this.conversation,
    this.trailing,
  });

  final Conversation conversation;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.hasUnread;
    final time = conversation.lastMessageAt != null
        ? formatConversationTime(conversation.lastMessageAt!)
        : '';
    final raw = conversation.lastMessage;
    final isImage = raw != null && raw.startsWith('[image]');
    final isAudio = raw != null && raw.startsWith('[audio]');
    final preview = isImage
        ? 'Imagen'
        : isAudio
            ? 'Audio'
            : raw ?? 'Conversación iniciada';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConversationAvatar(
            name: conversation.peerName,
            photoUrl: conversation.peerPhoto,
            radius: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conversation.peerName,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight:
                              hasUnread ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (time.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: TextStyle(
                          color: hasUnread
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (isImage) ...[
                      Icon(
                        Icons.photo_camera_outlined,
                        size: 14,
                        color: hasUnread
                            ? AppTheme.textPrimary.withValues(alpha: 0.85)
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (isAudio) ...[
                      Icon(
                        Icons.mic_rounded,
                        size: 14,
                        color: hasUnread
                            ? AppTheme.textPrimary.withValues(alpha: 0.85)
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasUnread
                              ? AppTheme.textPrimary.withValues(alpha: 0.9)
                              : AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight:
                              hasUnread ? FontWeight.w500 : FontWeight.w400,
                          fontStyle:
                              raw == null ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ),
                    if (hasUnread) ...[
                      const SizedBox(width: 8),
                      ConversationUnreadBadge(count: conversation.unreadCount),
                    ],
                    if (trailing != null) trailing!,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ConversationAvatar extends StatelessWidget {
  const ConversationAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 24,
  });

  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      final cacheWidth =
          (diameter * MediaQuery.devicePixelRatioOf(context)).ceil();
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: photoUrl!,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          memCacheWidth: cacheWidth,
          maxWidthDiskCache: cacheWidth,
          fadeInDuration: const Duration(milliseconds: 120),
          placeholder: (_, __) => CircleAvatar(
            radius: radius,
            backgroundColor: AppTheme.surfaceElevated,
          ),
          errorWidget: (_, __, ___) => _initialsAvatar(),
        ),
      );
    }
    return _initialsAvatar();
  }

  Widget _initialsAvatar() {
    final colors = [
      const Color(0xFF1A7F64),
      const Color(0xFF0063CB),
      const Color(0xFF8B4E96),
      const Color(0xFFD14343),
      const Color(0xFFE07B39),
      const Color(0xFF2D8A72),
    ];
    final color = colors[name.codeUnitAt(0) % colors.length];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.85,
        ),
      ),
    );
  }
}

class ConversationUnreadBadge extends StatelessWidget {
  const ConversationUnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

String formatConversationTime(DateTime dt) {
  final now = DateTime.now();
  final local = dt.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final msgDay = DateTime(local.year, local.month, local.day);
  final diff = today.difference(msgDay).inDays;

  if (diff == 0) {
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  if (diff == 1) return 'Ayer';
  if (diff < 7) {
    const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return days[(local.weekday - 1) % 7];
  }
  return '${local.day}/${local.month}/${local.year % 100}';
}

Future<bool> confirmDeleteConversation(
  BuildContext context, {
  required String peerName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(
        '¿Eliminar chat con $peerName?',
        style: const TextStyle(color: AppTheme.textPrimary),
      ),
      content: const Text(
        'Se ocultará solo para ti. El otro interlocutor seguirá viendo la conversación. '
        'Si te escriben de nuevo, el chat volverá a aparecer.',
        style: TextStyle(color: AppTheme.textSecondary, height: 1.35),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF453A)),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return result == true;
}
