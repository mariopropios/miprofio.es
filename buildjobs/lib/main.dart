import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('es', null);

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      detectSessionInUri: false,
    ),
  );

  // ── Firebase (push notifications) ────────────────────────────────────────
  // Solo inicializar si las variables de entorno están configuradas.
  final firebaseProjectId = dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  if (firebaseProjectId.isNotEmpty) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey:            dotenv.env['FIREBASE_API_KEY']            ?? '',
        authDomain:        dotenv.env['FIREBASE_AUTH_DOMAIN']        ?? '',
        projectId:         firebaseProjectId,
        storageBucket:     dotenv.env['FIREBASE_STORAGE_BUCKET']     ?? '',
        messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']?? '',
        appId:             dotenv.env['FIREBASE_APP_ID']             ?? '',
      ),
    );
  }

  runApp(
    const ProviderScope(
      child: ProfioApp(),
    ),
  );
}
