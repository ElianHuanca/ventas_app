import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración y acceso centralizado al cliente de Supabase.
///
/// La `publishableKey` (sb_publishable_...) está pensada para usarse en el
/// cliente y es pública. La seguridad real se controla con las políticas
/// RLS definidas en `supabase/schema.sql`.
///
/// Por defecto apunta a producción. Para apuntar a otra base (p. ej. el
/// Supabase local de `supabase start`) se pasan por `--dart-define`:
///
/// ```bash
/// flutter run --dart-define-from-file=env/local.json
/// ```
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://tacgylhmwqkfhdkpcvkr.supabase.co',
  );
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_sv1GE4d_2rZImM37tGMb7w_nzQDMwhf',
  );

  /// `true` si la app corre contra una base que no es la de producción.
  static bool get isLocal => !url.contains('tacgylhmwqkfhdkpcvkr');

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
