import 'dart:async';

import 'package:flutter/foundation.dart';

const rutaLogin = '/login';

/// Regla del `redirect` de GoRouter: sin sesión todo va a /login; con sesión,
/// /login vuelve al inicio. `null` = dejar pasar.
String? redireccionPorSesion(
    {required bool haySesion, required String ubicacion}) {
  final enLogin = ubicacion == rutaLogin;
  if (!haySesion) return enLogin ? null : rutaLogin;
  if (enLogin) return '/';
  return null;
}

/// Avisa al router (refreshListenable) cuando se entra o se sale de la
/// sesión, para que vuelva a evaluar el redirect.
class SesionListenable extends ChangeNotifier {
  late final StreamSubscription<bool> _sub;

  SesionListenable(Stream<bool> cambiosDeSesion) {
    _sub = cambiosDeSesion.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}
