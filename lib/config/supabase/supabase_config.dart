import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración y acceso centralizado al cliente de Supabase.
///
/// La `publishableKey` (sb_publishable_...) está pensada para usarse en el
/// cliente y es pública. La seguridad real se controla con las políticas
/// RLS definidas en `supabase/schema.sql`.
class SupabaseConfig {
  static const String url = 'https://tacgylhmwqkfhdkpcvkr.supabase.co';
  static const String publishableKey =
      'sb_publishable_sv1GE4d_2rZImM37tGMb7w_nzQDMwhf';

  /// Inicializa Supabase. Llamar una sola vez en `main()` antes de `runApp`.
  static Future<void> init() async {
    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
    );
  }

  /// Cliente compartido para todos los datasources.
  static SupabaseClient get client => Supabase.instance.client;
}
