// Las capturas de cada pantalla, armadas una vez y repetidas en varios
// dispositivos (Dispositivo, en golden_helpers.dart): pantalla chica con letra
// grande (pantalla_chica/), el teléfono acostado (apaisado/) y una tablet
// vertical (tablet/). Usan los mismos fakes y fechas fijas que las capturas
// de test/goldens/<feature>/.
//
// Cada `capturasDe...(d)` registra un testWidgets por pantalla, con el PNG
// `goldens/<pantalla>_<sufijo>.png` al lado del test que la llama. Con
// `todosLosEstados` agrega los estados principales que cambian el layout
// (alta, vacío, error, diálogo, otra pestaña); sin él, uno por pantalla.
// `omitidas` saltea las pantallas que en ese dispositivo tienen un bug
// conocido: el test que llama lleva el `// bug: archivo:línea — qué pasa`.
export 'apliques.dart';
export 'colores.dart';
export 'dashboard_login_menu.dart';
export 'fabricacion.dart';
export 'fotos.dart';
export 'inventario.dart';
export 'sucursales.dart';
export 'telas.dart';
export 'venta_apliques.dart';
export 'ventas.dart';
