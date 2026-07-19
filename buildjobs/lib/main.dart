import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/utils/pwa_setup_helper.dart';
import 'features/auth/data/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  // No bloquear el arranque si falla el locale (comun en hot-restart web).
  try {
    await initializeDateFormatting('es', null);
  } catch (e) {
    debugPrint('Locale es no cargado, fechas en formato por defecto: $e');
  }

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        detectSessionInUri: true,
      ),
    );
  } catch (e, st) {
    // Passkeys/SDK web no debe tumbar el arranque.
    debugPrint('Supabase.initialize fallido: $e\n$st');
  }

  // Recuperacion de contrasena: token_hash (email) o code (PKCE mismo navegador).
  try {
    await AuthRepository().completePasswordRecoveryFromUrl(Uri.base);
  } on AuthException catch (e) {
    debugPrint('Enlace de recuperacion: ${e.message}');
  } catch (e) {
    debugPrint('Enlace de recuperacion: $e');
  }

  // Firebase (push notifications)
  final firebaseProjectId = dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  if (firebaseProjectId.isNotEmpty) {
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: dotenv.env['FIREBASE_API_KEY'] ?? '',
          authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '',
          projectId: firebaseProjectId,
          storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
          messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
          appId: dotenv.env['FIREBASE_APP_ID'] ?? '',
        ),
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Firebase no inicializado, push desactivado: $e');
    }
  }

  if (kIsWeb) {
    initPwaSetupListener();
  }

  runApp(
    const ProviderScope(
      child: ProfioApp(),
    ),
  );
}
