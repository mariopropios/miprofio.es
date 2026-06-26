import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notification_service.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/client_register_screen.dart';
import '../../features/auth/presentation/screens/professional_register_screen.dart';
import '../../features/auth/presentation/screens/professional_register_success_screen.dart';
import '../../features/auth/presentation/models/registered_professional_preview.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/companies/presentation/screens/company_detail_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/edit_client_profile_screen.dart';
import '../../features/profile/presentation/screens/edit_professional_profile_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/conversations_screen.dart';
import '../../features/reviews/presentation/screens/write_review_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/shell/presentation/screens/main_shell.dart';
import '../providers/repository_providers.dart';
import 'routes.dart';

// ── Navigator keys ─────────────────────────────────────────────────────────────

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

// ── Auth notifier ─────────────────────────────────────────────────────────────
// ChangeNotifier que avisa a GoRouter cada vez que el auth state cambia,
// forzando la re-evaluación del redirect.

class _AuthRouteNotifier extends ChangeNotifier {
  _AuthRouteNotifier(Ref ref) {
    ref.listen<AsyncValue<AuthState>>(
      authStateProvider,
      (_, __) => notifyListeners(),
    );
  }
}

// ── Rutas que requieren sesión activa ─────────────────────────────────────────

bool _requiresAuth(String path) {
  return path.startsWith(AppRoutes.conversations) ||
      path.startsWith(AppRoutes.editProfile) ||
      path.startsWith(AppRoutes.writeReview) ||
      // Chat individual: /messages/:professionalId
      (path.startsWith('/messages/') && path.length > '/messages/'.length);
}

// ── Router provider ───────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthRouteNotifier(ref);
  ref.onDispose(authNotifier.dispose);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    // La app siempre arranca en Home (pública).
    // Si hay sesión activa, el usuario simplemente verá su estado de logueado.
    // Si no hay sesión, la Home funciona igual de forma anónima.
    initialLocation: AppRoutes.home,

    // GoRouter re-evalúa redirect() cada vez que authNotifier notifica.
    refreshListenable: authNotifier,

    // ── Gatekeeper ──────────────────────────────────────────────────────────
    redirect: (context, state) {
      // Comprobación síncrona: el SDK de Supabase restaura la sesión desde
      // localStorage antes de que Flutter pinte el primer frame.
      final session = Supabase.instance.client.auth.currentSession;
      final isAuthenticated = session != null;

      final path = state.matchedLocation;

      // Si la ruta requiere auth y no hay sesión → Login con redirect de vuelta
      if (!isAuthenticated && _requiresAuth(path)) {
        return AppRoutes.loginWithRedirect(path);
      }

      return null; // Sin redirección: renderizar la ruta solicitada
    },

    routes: [
      // ── Shell (barra de navegación inferior / lateral) ───────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.search,
            pageBuilder: (context, state) => NoTransitionPage(
              child: SearchScreen(
                initialProfession: state.uri.queryParameters['profession'],
                initialQuery: state.uri.queryParameters['q'],
                initialCategoryId: state.uri.queryParameters['cat'],
                initialCity: state.uri.queryParameters['city'],
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.conversations,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ConversationsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.editProfile,
            pageBuilder: (context, state) {
              final kind = state.uri.queryParameters['kind'];
              return NoTransitionPage(
                child: kind == 'professional'
                    ? const EditProfessionalProfileScreen()
                    : const EditClientProfileScreen(),
              );
            },
          ),
        ],
      ),

      // ── Pantallas a pantalla completa (sin shell) ────────────────────────
      GoRoute(
        path: AppRoutes.chat,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final professionalId = state.pathParameters['professionalId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return ChatScreen(
            professionalId: professionalId,
            professionalName: extra?['name'] as String? ?? 'Profesional',
            professionalPhoto: extra?['photo'] as String?,
            conversationId: extra?['conversationId'] as String?,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.companyDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CompanyDetailScreen(companyId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.writeReview,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return WriteReviewScreen(companyId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.login,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => LoginScreen(
          redirectTo: state.uri.queryParameters['redirect'],
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => RegisterScreen(
          redirectTo: state.uri.queryParameters['redirect'],
        ),
        routes: [
          GoRoute(
            path: 'client',
            builder: (context, state) => ClientRegisterScreen(
              redirectTo: state.uri.queryParameters['redirect'],
            ),
          ),
          GoRoute(
            path: 'professional',
            builder: (context, state) => ProfessionalRegisterScreen(
              redirectTo: state.uri.queryParameters['redirect'],
            ),
            routes: [
              GoRoute(
                path: 'success',
                builder: (context, state) {
                  final preview =
                      state.extra as RegisteredProfessionalPreview?;
                  if (preview == null) {
                    return const Scaffold(
                      body: Center(child: Text('Perfil no encontrado')),
                    );
                  }
                  return ProfessionalRegisterSuccessScreen(preview: preview);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );

  // ── Listener global de Auth ───────────────────────────────────────────────
  // Reacciona a eventos de sesión para limpiar estado y navegar.
  ref.listen<AsyncValue<AuthState>>(
    authStateProvider,
    (_, next) {
      next.whenData((authState) {
        switch (authState.event) {
          case AuthChangeEvent.signedOut:
            // Limpiar todos los providers de usuario
            ref.invalidate(currentProfileProvider);
            ref.invalidate(currentProfessionalProfileProvider);
            ref.invalidate(currentUserProfessionalViewProvider);
            // Borrar token FCM y redirigir a Home
            _tryDisableNotifications();
            router.go(AppRoutes.home);

          case AuthChangeEvent.initialSession:
          case AuthChangeEvent.signedIn:
          case AuthChangeEvent.tokenRefreshed:
          case AuthChangeEvent.userUpdated:
            // Refrescar datos del usuario con la nueva sesión
            ref.invalidate(currentProfileProvider);
            ref.invalidate(currentProfessionalProfileProvider);
            ref.invalidate(currentUserProfessionalViewProvider);
            // Inicializar notificaciones push si Firebase está disponible
            _tryEnableNotifications();

          default:
            break;
        }
      });
    },
  );

  return router;
});

// ── Helpers para notificaciones push ─────────────────────────────────────────

void _tryEnableNotifications() {
  try {
    // Firebase.apps.isNotEmpty garantiza que Firebase está inicializado
    if (Firebase.apps.isNotEmpty) {
      NotificationService.init();
    }
  } catch (_) {
    // Firebase no configurado → ignorar silenciosamente
  }
}

void _tryDisableNotifications() {
  try {
    if (Firebase.apps.isNotEmpty) {
      NotificationService.clearToken();
    }
  } catch (_) {}
}
