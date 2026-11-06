---
description: Fotos de telas y de apliques en Supabase Storage (bucket fotos): ver las activas, subir desde la galería o la cámara (solo celulares) achicadas y en un formato aceptado, una subida por vez, quitar sin borrar el archivo, la foto principal, y los límites y permisos del bucket.
---

# Spec: fotos

> Extraído automáticamente por spec-miner. Última extracción: 2026-11-06.
> Fuente: lib/features/fotos/ (foto.dart, fotos_datasource.dart, fotos_datasource_impl.dart, fotos_repository_impl.dart, fotos_cubit.dart, fotos_screen.dart), lib/features/shared/widgets/DialogoDeAlerta.dart, lib/features/shared/widgets/show_snackbar.dart, lib/features/telas/presentation/screens/telas_screen.dart, lib/features/apliques/presentation/screens/apliques_screen.dart, lib/config/router/app_router.dart, supabase/migrations/20261021000000_fotos_de_productos.sql, supabase/migrations/20260925000000_prod_schema.sql, supabase/migrations/20261003000100_integridad_stock_y_ventas.sql
> Last verified: 2026-11-06 (commit 1d15233)

---

### Requirement: Abrir las fotos de una tela o de un aplique
<!-- id: TelasScreen._telaCard -->
<!-- entities: ProductoConFotos, Tela, Aplique -->
<!-- enforced: TelasScreen._telaCard(), ApliquesScreen._apliqueCard() -->

Cada tarjeta del catálogo de telas y del catálogo de apliques DEBE tener un botón "Fotos" que abre la pantalla de fotos de ese producto. Las dos pantallas se comportan igual; solo cambian la tabla de fotos (`tela_fotos` o `aplique_fotos`) y la carpeta del almacenamiento (`telas/` o `apliques/`).

#### Scenario: Fotos de una tela
<!-- test: test/features/telas/presentation/screens/telas_screen_test.dart::"Fotos" navega a /tela-fotos/:id sin recargar al volver -->
- **WHEN** el usuario toca "Fotos" en la tarjeta de una tela
- **THEN** se abren las fotos de esa tela

#### Scenario: Fotos de un aplique
<!-- test: test/features/apliques/presentation/screens/apliques_screen_test.dart::"Fotos" navega a /aplique-fotos/:id sin recargar al volver -->
- **WHEN** el usuario toca "Fotos" en la tarjeta de un aplique
- **THEN** se abren las fotos de ese aplique

---

### Requirement: Ver las fotos activas de un producto
<!-- id: FotosCubit.cargar -->
<!-- entities: Foto, ProductoConFotos, tela_fotos, aplique_fotos -->
<!-- enforced: FotosCubit.cargar(), FotosDatasourceImpl.getNombre(), FotosDatasourceImpl.getFotos(), FotosScreen.build(), FotosScreen._cuerpo() -->

La pantalla DEBE consultar a la vez el nombre del producto y sus fotos con `activo = true`, y mostrar las fotos en una grilla de dos columnas en orden de id ascendente (orden de subida), cada una con el botón "Quitar foto". El título DEBE ser el nombre del producto o, si no se conoce, "Fotos de la tela" / "Fotos del aplique". Mientras carga DEBE verse un indicador de progreso. Una foto cuya imagen no se puede descargar se muestra con un ícono de imagen rota.

#### Scenario: Producto con fotos
<!-- test: test/features/fotos/presentation/screens/fotos_screen_test.dart::título con el nombre, una miniatura por foto y la principal -->
<!-- test: test/features/fotos/presentation/bloc/fotos_cubit_test.dart::al crearse carga el nombre y las fotos del producto -->
- **WHEN** se abren las fotos de un producto con fotos activas
- **THEN** el título es el nombre del producto y hay una miniatura por foto activa, en orden de subida

#### Scenario: Nombre desconocido
<!-- test: test/features/fotos/presentation/screens/fotos_screen_test.dart::sin nombre usa el título genérico de tela o de aplique -->
- **WHEN** el nombre del producto llega vacío
- **THEN** el título es "Fotos de la tela" o "Fotos del aplique" según el producto

#### Scenario: Producto sin fotos
<!-- test: test/features/fotos/presentation/screens/fotos_screen_test.dart::sin fotos lo dice y aclara cuál se ve en la web -->
- **WHEN** el producto no tiene fotos activas
- **THEN** se ve "Todavía no tiene fotos." y "La primera es la que se ve en la web."

---

### Requirement: Reintentar cuando no se pudieron cargar las fotos
<!-- id: FotosCubit.cargar -->
<!-- entities: Foto -->
<!-- enforced: FotosCubit.cargar(), FotosScreen._cuerpo() -->

Si falla la consulta del nombre o la de las fotos (por ejemplo, sin conexión, o un producto que no existe), la pantalla DEBE mostrar "No se pudieron cargar las fotos. Revisá la conexión." y un botón "Reintentar" que vuelve a consultar ambas cosas.

#### Scenario: Sin conexión y reintento
<!-- test: test/features/fotos/presentation/screens/fotos_screen_test.dart::sin conexión avisa del error y reintentar recupera -->
<!-- test: test/features/fotos/presentation/bloc/fotos_cubit_test.dart::si la carga falla marca error; reintentar lo recupera -->
- **WHEN** la carga falla y después el usuario toca "Reintentar" con conexión
- **THEN** primero se ve el aviso con "Reintentar" y luego las fotos del producto

---

### Requirement: Subir una foto desde la galería o la cámara
<!-- id: FotosScreen._agregar -->
<!-- entities: FotoElegida, Foto, tela_fotos, aplique_fotos -->
<!-- enforced: FotosScreen._agregar(), fotos_screen.elegirFotoDelSistema(), FotosCubit.subir(), FotosDatasourceImpl.subirFoto(), fotos_datasource_impl.rutaDeFoto() -->

"Galería" y "Cámara" DEBEN abrir el selector de imágenes del sistema y pedir la imagen achicada a 1600 px por lado como máximo, con calidad 80. Con la imagen elegida, la app DEBE subir el archivo al bucket público `fotos` en `<telas|apliques>/<id del producto>/<milisegundos>_<8 dígitos hex aleatorios>.<extensión>` (un nombre que no se repite), registrar una fila activa en `tela_fotos` o `aplique_fotos` con la URL pública del archivo y agregar la foto al final de la grilla. Si el usuario no elige nada, NO DEBE subirse nada.

#### Scenario: Subir desde la galería
<!-- test: test/features/fotos/presentation/screens/fotos_screen_test.dart::"Galería" elige de la galería y sube la foto -->
<!-- test: test/features/fotos/presentation/bloc/fotos_cubit_test.dart::subir agrega la foto al final y avisa que salió bien -->
- **WHEN** el usuario toca "Galería" y elige una imagen
- **THEN** el archivo se sube, queda una fila activa con su URL pública y la foto aparece al final de la grilla

#### Scenario: Sacar con la cámara
<!-- test: test/features/fotos/presentation/screens/fotos_screen_test.dart::"Cámara" saca la foto con la cámara -->
- **WHEN** el usuario toca "Cámara" y saca una foto
- **THEN** la foto se sube igual que una de la galería

#### Scenario: Cancelar la selección
<!-- test: test/features/fotos/presentation/screens/fotos_screen_test.dart::si no elige nada no sube -->
- **WHEN** el usuario cierra el selector sin elegir
- **THEN** no se sube nada y la grilla no cambia

#### Scenario: Ubicación del archivo
<!-- test: test/features/fotos/infrastructure/fotos_datasource_impl_test.dart::rutaDeFoto: carpeta por producto y nombre que no se repite -->
<!-- test: test/features/fotos/infrastructure/fotos_datasource_impl_test.dart::cada producto apunta a su tabla, columna y carpeta -->
- **WHEN** se sube un JPEG para la tela 12
- **THEN** el archivo queda en `telas/12/` con un nombre `<milisegundos>_<8 hex>.jpg`

---

### Requirement: Subir la foto en un formato que acepta el almacenamiento
<!-- id: fotos_screen.extensionDeFoto -->
<!-- entities: FotoElegida -->
<!-- enforced: fotos_screen.extensionDeFoto(), fotos_datasource_impl.tipoMime() -->

La extensión DEBE tomarse del nombre del archivo elegido sin distinguir mayúsculas: "png" se sube como PNG (`image/png`), "webp" como WebP (`image/webp`) y cualquier otra, o ninguna, como JPEG (`.jpg`, `image/jpeg`).

#### Scenario: Extensión conocida
<!-- test: test/features/fotos/infrastructure/fotos_datasource_impl_test.dart::extensionDeFoto: normaliza y lo desconocido se sube como jpg -->
<!-- test: test/features/fotos/infrastructure/fotos_datasource_impl_test.dart::tipoMime: los tres que acepta el bucket -->
- **WHEN** el archivo elegido se llama "IMG_1.PNG"
- **THEN** se sube con extensión "png" y tipo `image/png`

#### Scenario: Extensión desconocida
<!-- test: test/features/fotos/infrastructure/fotos_datasource_impl_test.dart::extensionDeFoto: normaliza y lo desconocido se sube como jpg -->
- **WHEN** el archivo no tiene extensión o tiene otra (por ejemplo "heic")
- **THEN** se sube con extensión "jpg" y tipo `image/jpeg`

---

### Requirement: Ofrecer la cámara solo en celulares
<!-- id: fotos_screen.hayCamara -->
<!-- entities: ProductoConFotos -->
<!-- enforced: fotos_screen.hayCamara(), FotosScreen._cuerpo() -->

El botón "Cámara" DEBE aparecer solo en Android e iOS; en escritorio (por ejemplo Windows) y en web DEBE ofrecerse solo "Galería".

#### Scenario: Escritorio
<!-- test: test/features/fotos/presentation/screens/fotos_screen_test.dart::sin cámara (Windows) solo ofrece la galería -->
- **WHEN** la app corre en Windows
- **THEN** solo se ve el botón "Galería"

#### Scenario: Celular
<!-- test: test/features/fotos/presentation/screens/fotos_screen_test.dart::"Cámara" saca la foto con la cámara -->
- **WHEN** la app corre en Android o iOS
- **THEN** se ven "Galería" y "Cámara"

---

### Requirement: No permitir dos subidas a la vez
<!-- id: FotosCubit.subir -->
<!-- entities: Foto -->
<!-- enforced: FotosCubit.subir(), FotosScreen._cuerpo() -->

Mientras se sube una foto DEBEN verse una barra de progreso y "Subiendo foto…", y los botones "Galería" y "Cámara" DEBEN quedar deshabilitados; un segundo pedido de subida en ese momento NO DEBE subir nada.

#### Scenario: Subida en curso
<!-- test: test/features/fotos/presentation/screens/fotos_screen_test.dart::mientras sube muestra el progreso y deshabilita los botones -->
<!-- test: test/features/fotos/presentation/bloc/fotos_cubit_test.dart::mientras sube marca subiendo y no deja subir otra a la vez -->
- **WHEN** una foto se está subiendo
- **THEN** se ve el progreso, los botones están deshabilitados y otra subida es rechazada

---

### Requirement: Avisar cuando no se pudo abrir o subir la foto
<!-- id: FotosScreen._agregar -->
<!-- entities: Foto, FotoElegida -->
<!-- enforced: FotosScreen._agregar(), FotosCubit.subir() -->

Si el selector del sistema falla (por ejemplo, permiso de cámara o galería negado), DEBE avisarse "No se pudo abrir la foto". Si la subida o el registro de la foto fallan (sin conexión, archivo de más de 5 MB, tipo no permitido), DEBE avisarse "No se pudo subir la foto. Revisá la conexión." y la grilla NO DEBE cambiar.

#### Scenario: Permiso negado
<!-- test: test/features/fotos/presentation/screens/fotos_screen_test.dart::si no se puede abrir la galería (permiso) avisa -->
- **WHEN** el sistema no deja abrir la galería o la cámara
- **THEN** se ve "No se pudo abrir la foto" y no se sube nada

#### Scenario: Falla la subida
<!-- test: test/features/fotos/presentation/screens/fotos_screen_test.dart::si la subida falla avisa y no agrega la foto -->
<!-- test: test/features/fotos/presentation/bloc/fotos_cubit_test.dart::si subir falla no agrega nada y devuelve false -->
- **WHEN** la subida falla
- **THEN** se ve "No se pudo subir la foto. Revisá la conexión." y la grilla queda igual

<!-- revisar: fotos_datasource_impl.dart:48-57 — primero sube el archivo y después inserta la fila: si el insert falla, el archivo queda huérfano en el bucket (nadie puede borrarlo) y el reintento sube otro archivo nuevo. -->

---

### Requirement: Quitar una foto sin borrar el archivo
<!-- id: FotosScreen._confirmarQuitar -->
<!-- entities: Foto, tela_fotos, aplique_fotos -->
<!-- enforced: FotosScreen._confirmarQuitar(), dialogoDeAlerta(), FotosCubit.quitar(), FotosDatasourceImpl.quitarFoto() -->

"Quitar foto" DEBE pedir confirmación con el título "Quitar foto", el mensaje "Deja de verse en la app y en la web." y los botones "Cancelar" y "Quitar". Al confirmar DEBE marcar la fila con `activo = false` (el archivo queda en el almacenamiento) y sacar la foto de la grilla recién cuando la base respondió; si falla, DEBE avisar "No se pudo quitar la foto" y la foto DEBE seguir en la grilla. Cancelar NO DEBE cambiar nada.

#### Scenario: Confirmar
<!-- test: test/features/fotos/presentation/screens/fotos_screen_test.dart::quitar pide confirmación y saca la foto -->
<!-- test: test/features/fotos/presentation/bloc/fotos_cubit_test.dart::quitar la saca de la lista (baja lógica en el repositorio) -->
- **WHEN** el usuario toca "Quitar foto" y confirma con "Quitar"
- **THEN** la fila queda con `activo = false` y la foto sale de la grilla

#### Scenario: Cancelar
<!-- test: test/features/fotos/presentation/screens/fotos_screen_test.dart::cancelar la confirmación no quita nada -->
- **WHEN** el usuario toca "Quitar foto" y luego "Cancelar"
- **THEN** la foto sigue en la grilla y en la base

#### Scenario: Falla al quitar
<!-- test: test/features/fotos/presentation/bloc/fotos_cubit_test.dart::si quitar falla la foto sigue en la lista -->
- **WHEN** la baja de la foto falla
- **THEN** se ve "No se pudo quitar la foto" y la foto sigue en la grilla

---

### Invariant: La foto principal es la activa más antigua
<!-- entities: Foto, tela_fotos, aplique_fotos, catalogo_telas_web, catalogo_apliques_web -->
<!-- enforced: FotosDatasourceImpl.getFotos(), FotosScreen._cuerpo(), 20261021000000_fotos_de_productos.sql:catalogo_telas_web, 20261021000000_fotos_de_productos.sql:catalogo_apliques_web -->
<!-- verified_by: test/features/fotos/presentation/screens/fotos_screen_test.dart::título con el nombre, una miniatura por foto y la principal -->
<!-- verified_by: supabase/tests/database/07_vistas_web.test.sql::catalogo_apliques_web: fotos activas por id y foto = la primera -->

La foto principal de un producto DEBE ser siempre la foto activa de menor id: en la app es la primera de la grilla y lleva la marca "Principal" (lector de pantalla: "Foto principal"; las demás, "Foto"), y en los catálogos web es la `foto` publicada y la primera de `fotos`. Quitar la principal convierte en principal a la siguiente activa.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: El almacenamiento de fotos es público y acepta solo imágenes de hasta 5 MB
<!-- entities: storage.buckets -->
<!-- enforced: 20261021000000_fotos_de_productos.sql:INSERT INTO storage.buckets ('fotos') -->
<!-- verified_by: supabase/tests/database/01_rls_y_permisos.test.sql::bucket fotos: público (la web lee la URL sin sesión), hasta 5 MB y solo imágenes -->

El bucket `fotos` DEBE ser de lectura pública (la URL se abre sin sesión), con un límite de 5 MB por archivo y solo los tipos `image/jpeg`, `image/png` e `image/webp`.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Solo un usuario con sesión sube fotos y nadie modifica ni borra archivos
<!-- entities: storage.objects -->
<!-- enforced: 20261021000000_fotos_de_productos.sql:fotos_subir_logueados -->
<!-- verified_by: supabase/tests/database/01_rls_y_permisos.test.sql::storage: la única política es subir a fotos con sesión (nadie modifica ni borra archivos) -->
<!-- verified_by: supabase/tests/database/01_rls_y_permisos.test.sql::authenticated puede subir al bucket fotos -->
<!-- verified_by: supabase/tests/database/01_rls_y_permisos.test.sql::anon no puede subir al bucket fotos -->

Solo un usuario con sesión DEBE poder agregar archivos, y solo al bucket `fotos`; ningún usuario DEBE poder modificar ni borrar archivos ya subidos.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Las filas de fotos nunca se borran físicamente
<!-- entities: tela_fotos, aplique_fotos -->
<!-- enforced: 20261003000100_integridad_stock_y_ventas.sql:REVOKE DELETE ON tela_fotos, 20261021000000_fotos_de_productos.sql:GRANT SELECT, INSERT, UPDATE ON aplique_fotos -->
<!-- verified_by: supabase/tests/database/01_rls_y_permisos.test.sql::DELETE físico solo en ventas y detalle_ventas -->

Ningún usuario de la app DEBE poder borrar filas de `tela_fotos` ni de `aplique_fotos`: quitar una foto es siempre `activo = false`, y las fotos con `activo = false` NO DEBEN mostrarse en la app ni publicarse en la web.

> Last verified: 2026-11-06 (commit 1d15233)

<!-- uncertainty: el achicado (1600 px, calidad 80) lo hace el selector del sistema (image_picker); no se verificó si convierte a JPEG las imágenes PNG/HEIC en cada plataforma, por eso la extensión sale del nombre del archivo elegido. -->
<!-- uncertainty: la integración no sube fotos (la CI levanta Supabase sin storage-api); la subida real solo está cubierta por fakes y por pgTAP del bucket. -->
