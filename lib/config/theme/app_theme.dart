//import 'dart:math';

import 'package:flutter/material.dart';

const scaffoldBackgroundColor = Color(0xFFF8F7F7);
const colorSeed = Color(0xff424CB8);

TextStyle _textStyle(double size, {FontWeight? weight}) {
  return TextStyle(fontSize: size, fontWeight: weight);
}

class AppTheme {
  ThemeData getTheme() {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: colorSeed,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      textTheme: TextTheme(
        titleLarge: _textStyle(40, weight: FontWeight.bold),
        titleMedium: _textStyle(30, weight: FontWeight.bold),
        titleSmall: _textStyle(20),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            _textStyle(14, weight: FontWeight.w700),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackgroundColor,
        titleTextStyle: _textStyle(25, weight: FontWeight.bold)
            .copyWith(color: Colors.black),
      ),
    );
  }
}
