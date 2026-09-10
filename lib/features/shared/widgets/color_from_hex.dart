import 'package:flutter/material.dart';

Color colorFromHex(String hex) {
  var value = hex.replaceAll('#', '');
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return const Color(0xFF000000);
  return Color(int.tryParse(value, radix: 16) ?? 0xFF000000);
}
