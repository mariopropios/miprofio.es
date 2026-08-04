import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_callback_service.dart';
import '../services/notification_service.dart';
import '../services/post_email_confirm_redirect.dart';

import '../../features/auth/presentation/screens/email_verification_screen.dart';
import '../../features/auth/presentation/screens/auth_confirm_screen.dart';
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
import '../../features/chat/presentation/screens/conversations_screen.dart';
import '../../features/chat/presentation/screens/archived_conversations_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/models/active_chat_route.dart';
import '../../features/reviews/presentation/screens/write_review_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/shell/presentation/screens/main_shell.dart';
import '../../features/about/presentation/screens/about_feedback_screen.dart';
import '../../features/deep_link/presentation/screens/go_handoff_screen.dart';
import '../../features/local_seo/presentation/screens/local_seo_hub_screen.dart';
import '../../features/local_seo/presentation/screens/local_seo_profession_screen.dart';
import '../../shared/widgets/legal_document_screen.dart';
import '../constants/local_seo.dart';
import '../legal/legal_documents.dart';
import '../providers/repository_providers.dart';
import '../services/tab_coordinator.dart';
import 'routes.dart';
import 'slide_page.dart';

// ── Navigator keys ─────────────────────────────────────────────────────────────

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

Page<void> _buildMessagesHubPage(GoRouterState state) {
  return const NoTransitionPage(
    key: ValueKey<String>('messages-hub'),
    child: ConversationsScreen(),
  );
}

Page<void> _buildChatPage(GoRouterState state) {
  final active = ActiveChatRoute.fromRouterState(state);
  if (active == null) {
    return const NoTransitionPage(child: SizedBox.shrink());
  }
  return slidePage<void>(
    key: state.pageKey,
    child: ChatScreen(
      professionalId: active.professionalId,
      professionalName: active.name ?? 'Profesional',
      professionalPhoto: active.photo,
      conversationId: active.conversationId,
      peerUserId: active.peerUserId,
      viewingAsProfessional: active.viewingAsProfessional,
    ),
  );
}

String? _legacyChatPathRedirect(GoRouterState state) {
  final segments = state.uri.pathSegments;
  if (segments.length == 3 &&
      segments[0] == 'messages' &&
      segments[1] == 'chat') {
    return Uri(
      path: '/messages/${segments[2]}',
      queryParameters: state.uri.queryParameters,
    ).toString();
  }
  return null;
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
  if (path == AppRoutes.go) return false;
  return path.startsWith(AppRoutes.conversations) ||
      path.startsWith(AppRoutes.editProfile) ||
      path == AppRoutes.savedProfessionals ||
      path.startsWith(AppRoutes.writeReview) ||
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
      final legacyChat = _legacyChatPathRedirect(state);
      if (legacyChat != null) return legacyChat;

      // Fail-soft si Supabase aún no está listo (p. ej. arranque iOS sin bundle).
      Session? session;
      try {
        session = Supabase.instance.client.auth.currentSession;
      } catch (_) {
        session = null;
      }
      final isAuthenticated = session != null;
      final path = state.matchedLocation;
      final isAuthCallback = AuthCallbackService.isAuthCallback(state.uri);

      // Recovery: ir a reset-password. Signup/email: lo gestiona /auth/confirm.
      if (isAuthenticated && isAuthCallback) {
        if (AuthCallbackService.isPasswordRecoveryCallback(state.uri)) {
          return AppRoutes.resetPassword;
        }
        if (state.uri.path != AppRoutes.authConfirm) {
          return AppRoutes.profileAfterEmailVerification();
        }
      }

      // /search?city=Candeleda(&profession=…) → URL limpia SEO local.
      if (path == AppRoutes.search) {
        final clean = LocalSeo.tryCleanSearchPath(
          city: state.uri.queryParameters['city'],
          profession: state.uri.queryParameters['q'] == null ||
                  state.uri.queryParameters['q']!.isEmpty
              ? state.uri.queryParameters['profession']
              : null,
        );
        if (clean != null &&
            (state.uri.queryParameters['q'] == null ||
                state.uri.queryParameters['q']!.isEmpty)) {
          return clean;
        }
      }

      // /auth/confirm publica borrador y redirige — no interceptar aquí.

      // No mandar a login hasta hidratar sesión (evita false login en deep link).
      final authAsync = ref.read(authStateProvider);
      final authReady = authAsync.hasValue || authAsync.hasError;

      if (!isAuthenticated && _requiresAuth(path)) {
        if (!authReady) return null;
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
          // Hubs + landings SEO local (La Vera). Rutas explícitas para no
          // capturar /login, /about, etc.
          ...LocalSeo.locations.map(
            (loc) => GoRoute(
              path: '/${loc.slug}',
              pageBuilder: (context, state) => NoTransitionPage(
                child: LocalSeoHubScreen(location: loc),
              ),
              routes: [
                GoRoute(
                  path: ':professionSlug',
                  redirect: (context, state) {
                    final slug = state.pathParameters['professionSlug'];
                    if (LocalSeo.professionBySlug(slug) == null) {
                      return '/${loc.slug}';
                    }
                    return null;
                  },
                  pageBuilder: (context, state) {
                    final slug = state.pathParameters['professionSlug']!;
                    final profession = LocalSeo.professionBySlug(slug)!;
                    return NoTransitionPage(
                      child: LocalSeoProfessionScreen(
                        location: loc,
                        profession: profession,
                      ),
                    );
                  },
                ),
              ],
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
            pageBuilder: (context, state) => _buildMessagesHubPage(state),
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

      GoRoute(
        path: AppRoutes.chat,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _buildChatPage(state),
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
        path: AppRoutes.archivedMessages,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => slidePage<void>(
          key: state.pageKey,
          child: const ArchivedConversationsScreen(),
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
        path: AppRoutes.go,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final to = state.uri.queryParameters['to'] ?? '';
          return NoTransitionPage<void>(
            key: state.pageKey,
            child: GoHandoffScreen(target: to),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.about,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => slidePage<void>(
          key: state.pageKey,
          child: const AboutFeedbackScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => slidePage<void>(
          key: state.pageKey,
          child: LegalDocumentScreen(document: LegalDocuments.privacy),
        ),
      ),
      GoRoute(
        path: AppRoutes.cookies,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => slidePage<void>(
          key: state.pageKey,
          child: LegalDocumentScreen(document: LegalDocuments.cookies),
        ),
      ),
      GoRoute(
        path: AppRoutes.terms,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => slidePage<void>(
          key: state.pageKey,
          child: LegalDocumentScreen(document: LegalDocuments.terms),
        ),
      ),
      GoRoute(
        path: AppRoutes.legalNotice,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => slidePage<void>(
          key: state.pageKey,
          child: LegalDocumentScreen(document: LegalDocuments.legalNotice),
        ),
      ),
      GoRoute(
        path: AppRoutes.authConfirm,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => slidePage<void>(
          key: state.pageKey,
          child: const AuthConfirmScreen(),
        ),
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

  // Deep links de email → reutilizar pestaña ya abierta.
  TabCoordinator.start();
  TabCoordinator.listenHandoffs((target) {
    try {
      router.go(target);
    } catch (e) {
      debugPrint('TabCoordinator handoff nav: $e');
    }
  });
  ref.onDispose(TabCoordinator.stopListeningHandoffs);

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
            final onAuthConfirm = Uri.base.path == AppRoutes.authConfirm;
            if (authState.session != null &&
                !onAuthConfirm &&
                AuthCallbackService.isAuthCallback(Uri.base)) {
              if (AuthCallbackService.isPasswordRecoveryCallback(Uri.base)) {
                router.go(AppRoutes.resetPassword);
              } else {
                PostEmailConfirmRedirect.resolve(
                  nextFromUrl:
                      AuthCallbackService.allParameters(Uri.base)['next'],
                ).then((dest) {
                  router.go(dest);
                });
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
