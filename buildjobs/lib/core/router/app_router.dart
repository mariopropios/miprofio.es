import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/client_register_screen.dart';
import '../../features/auth/presentation/screens/professional_register_screen.dart';
import '../../features/auth/presentation/screens/professional_register_success_screen.dart';
import '../../features/auth/presentation/models/registered_professional_preview.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/companies/presentation/screens/companies_list_screen.dart';
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
import 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    routes: [
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
});
