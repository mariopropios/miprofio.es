import 'package:go_router/go_router.dart';

/// Chat abierto encima de la lista de mensajes (misma pantalla, sin flash).
class ActiveChatRoute {
  const ActiveChatRoute({
    required this.professionalId,
    this.name,
    this.photo,
    this.conversationId,
    this.peerUserId,
    this.viewingAsProfessional = false,
  });

  final String professionalId;
  final String? name;
  final String? photo;
  final String? conversationId;
  final String? peerUserId;
  final bool viewingAsProfessional;

  static ActiveChatRoute? fromRouterState(GoRouterState state) {
    var professionalId = state.pathParameters['professionalId'];
    if (professionalId == null || professionalId.isEmpty) {
      final segments = state.uri.pathSegments;
      if (segments.length == 2 && segments.first == 'messages') {
        professionalId = segments[1];
      }
    }
    if (professionalId == null || professionalId.isEmpty) return null;

    final extra = state.extra as Map<String, dynamic>?;
    final qp = state.uri.queryParameters;
    String? decodeParam(String? value) =>
        value == null || value.isEmpty ? null : Uri.decodeComponent(value);

    return ActiveChatRoute(
      professionalId: professionalId,
      name: extra?['name'] as String? ?? decodeParam(qp['name']),
      photo: extra?['photo'] as String? ?? decodeParam(qp['photo']),
      conversationId:
          extra?['conversationId'] as String? ?? qp['conversationId'],
      peerUserId: extra?['peerUserId'] as String?,
      viewingAsProfessional:
          extra?['viewingAsProfessional'] as bool? ?? false,
    );
  }
}
