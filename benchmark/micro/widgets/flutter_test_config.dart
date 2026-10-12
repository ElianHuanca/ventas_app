// Los benchmarks de widgets montan con las fuentes reales (Roboto y
// MaterialIcons del SDK), igual que las capturas golden: con la fuente de
// prueba de flutter_test (Ahem, cada letra un cuadrado) el texto es más ancho
// que en el celular y el dashboard desborda a 412 dp, y el costo de maquetar
// texto tampoco sería el real.
export '../../../test/goldens/flutter_test_config.dart';
