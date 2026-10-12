// Los tests de accesibilidad montan las pantallas con las fuentes reales
// (Roboto y MaterialIcons del SDK), igual que las capturas golden: con la
// fuente de prueba de flutter_test (Ahem, cada letra un cuadrado) el texto es
// más ancho que en el celular y varias pantallas desbordan a 412 dp, y el
// contraste se mediría sobre glifos que no son los reales.
export '../goldens/flutter_test_config.dart';
