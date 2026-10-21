import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El build de release usa solo `android/app/src/main/AndroidManifest.xml`:
/// los de debug y profile agregan INTERNET por su cuenta, así que sin este
/// permiso en el principal la app de release no se conecta a Supabase y el
/// login dice "No se pudo iniciar sesión" (pasó el 2026-10-21).
void main() {
  test('el manifest principal pide el permiso de internet (release)', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(
      manifest,
      contains('<uses-permission android:name="android.permission.INTERNET"/>'),
    );
  });
}
