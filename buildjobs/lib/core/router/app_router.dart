import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_callback_service.dart';
import '../services/notification_service.dart';

import '../../features/auth/presentation/screens/email_verification_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/client_register_screen.dart';
import '../../features/auth/presentation/screens/professional_register_screen.dart';
import '../../features/auth/presentation/screens/professional_register_success_screen.dart';
import '../../features/auth/presentation/models/registered_professional_preview.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/companies/presentation/screens/company_detail_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/public_client_profile_screen.dart';
import '../../features/profile/presentation/screens/saved_professionals_screen.dart';
import '../../features/profile/presentation/screens/edit_client_profile_screen.dart';
import '../../features/profile/presentation/screens/edit_professional_profile_screen.dart';
import '../../features/chat/presentation/models/active_chat_route.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/conversations_screen.dart';
import '../../features/reviews/presentation/screens/write_review_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/shell/presentation/screens/main_shell.dart';
import '../providers/repository_providers.dart';
import 'routes.dart';
import 'slide_page.dart';

// ── Navigator keys ─────────────────────────────────────────────────────────────

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

NoTransitionPage<void> _buildChatPage(GoRouterState state) {
  final chat = ActiveChatRoute.fromRouterState(state);
  if (chat == null) {
    return const NoTransitionPage(
      key: ValueKey<String>('messages-list-fallback'),
      child: ConversationsScreen(),
    );
  }
  return NoTransitionPage(
    key: ValueKey<String>('messages-chat-${chat.professionalId}'),
    child: ChatScreen(
      professionalId: chat.professionalId,
      professionalName: chat.name ?? 'Profesional',
      professionalPhoto: chat.photo,
      conversationId: chat.conversationId,
      peerUserId: chat.peerUserId,
      viewingAsProfessional: chat.viewingAsProfessional,
    ),
  );
}

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
      path == AppRoutes.savedProfessionals ||
      path.startsWith(AppRoutes.writeReview) ||
      // Chat individual: /messages/:professionalId
      (path.startsWith('/messages/') && path.length > '/messages/'.length);
}

// ── Router provider ───────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthRouteNotifier(ref);
  ref.onDispose(authNotifier.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    // La app siempre arranca en Home (pública).
    // Si hay sesión activa, el usuario simplemente verá su estado de logueado.
    // Si no hay sesión, la Home funciona igual de forma anónima.
    initialLocation: AppRoutes.home,

    // GoRouter re-evalúa redirect() cada vez que authNotifier notifica.
    refreshListenable: authNotifier,

    // ── Gatekeeper ──────────────────────────────────────────────────────────
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuthenticated = session != null;
      final path = state.matchedLocation;
      final isAuthCallback = AuthCallbackService.isAuthCallback(state.uri);

      // Tras verificar email u OAuth: ir al perfil con sesión activa.
      if (isAuthenticated && isAuthCallback) {
        return AppRoutes.profileAfterEmailVerification();
      }

      if (!isAuthenticated && _requiresAuth(path)) {
        final redirect = state.uri.hasQuery
            ? '${state.uri.path}?${state.uri.query}'
            : path;
        return AppRoutes.loginWithRedirect(redirect);
      }

      return null;
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
              key: ValueKey<String>('messages-list'),
              child: ConversationsScreen(),
            ),
            routes: [
              GoRoute(
                path: ':professionalId',
                pageBuilder: (context, state) => _buildChatPage(state),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.editProfile,
            pageBuilder: (context, state) {
              final kind = state.uri.queryParameters['kind'];
              return slidePage<void>(
                key: state.pageKey,
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
        path: AppRoutes.userProfile,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return slidePage<void>(
            key: state.pageKey,
            child: PublicClientProfileScreen(userId: userId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.savedProfessionals,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => slidePage<void>(
          key: state.pageKey,
          child: const SavedProfessionalsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.companyDetail,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return slidePage<void>(
            key: state.pageKey,
            child: CompanyDetailScreen(companyId: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.writeReview,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return slidePage<void>(
            key: state.pageKey,
            child: WriteReviewScreen(companyId: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.login,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => slidePage<void>(
          key: state.pageKey,
          child: LoginScreen(
            redirectTo: state.uri.queryParameters['redirect'],
            initialEmail: state.uri.queryParameters['email'],
            existingAccountNotice:
                state.uri.queryParameters['existing'] == '1',
          ),
        ),
        routes: [
          GoRoute(
            path: 'forgot-password',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) => slidePage<void>(
              key: state.pageKey,
              child: ForgotPasswordScreen(
                initialEmail: state.uri.queryParameters['email'],
                redirectTo: state.uri.queryParameters['redirect'],
              ),
            ),
          ),
          GoRoute(
            path: 'reset-password',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) => slidePage<void>(
              key: state.pageKey,
              child: ResetPasswordScreen(
                redirectTo: state.uri.queryParameters['redirect'],
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.emailVerification,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return slidePage<void>(
            key: state.pageKey,
            child: EmailVerificationScreen(email: email),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.register,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => slidePage<void>(
          key: state.pageKey,
          child: RegisterScreen(
            redirectTo: state.uri.queryParameters['redirect'],
          ),
        ),
        routes: [
          GoRoute(
            path: 'client',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) => slidePage<void>(
              key: state.pageKey,
              child: ClientRegisterScreen(
                redirectTo: state.uri.queryParameters['redirect'],
              ),
            ),
          ),
          GoRoute(
            path: 'professional',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) => slidePage<void>(
              key: state.pageKey,
              child: ProfessionalRegisterScreen(
                redirectTo: state.uri.queryParameters['redirect'],
              ),
            ),
            routes: [
              GoRoute(
                path: 'success',
                parentNavigatorKey: rootNavigatorKey,
                pageBuilder: (context, state) {
                  final preview =
                      state.extra as RegisteredProfessionalPreview?;
                  return slidePage<void>(
                    key: state.pageKey,
                    child: preview == null
                        ? const Scaffold(
                            body: Center(child: Text('Perfil no encontrado')),
                          )
                        : ProfessionalRegisterSuccessScreen(preview: preview),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );

  NotificationService.attachRouter(router);

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

          case AuthChangeEvent.passwordRecovery:
            router.go(AppRoutes.resetPassword);

          case AuthChangeEvent.initialSession:
          case AuthChangeEvent.signedIn:
          case AuthChangeEvent.tokenRefreshed:
          case AuthChangeEvent.userUpdated:
            ref.invalidate(currentProfileProvider);
            ref.invalidate(currentProfessionalProfileProvider);
            ref.invalidate(currentUserProfessionalViewProvider);
            _trySyncNotifications();
            if (authState.session != null &&
                AuthCallbackService.isAuthCallback(Uri.base)) {
              if (AuthCallbackService.isPasswordRecoveryCallback(Uri.base)) {
                router.go(AppRoutes.resetPassword);
              } else {
                router.go(AppRoutes.profileAfterEmailVerification());
              }
            }

          default:
            break;
        }
      });
    },
  );

  return router;
});

// ── Helpers para notificaciones push ─────────────────────────────────────────

void _trySyncNotifications() {
  try {
    if (Firebase.apps.isNotEmpty) {
      NotificationService.syncIfAlreadyAuthorized();
    }
  } catch (_) {}
}

void _tryDisableNotifications() {
  try {
    if (Firebase.apps.isNotEmpty) {
      NotificationService.clearToken();
    }
  } catch (_) {}
}
