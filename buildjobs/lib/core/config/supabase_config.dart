import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static String get url => dotenv.env['SUPABASE_URL'] ?? '';
  static String get publishableKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '';

  /// Alias de compatibilidad
  static String get anonKey => publishableKey;

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
