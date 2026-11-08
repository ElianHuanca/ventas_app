---
description: Ingreso con Supabase Auth. Cubre la redirección a la pantalla de ingreso sin sesión y al inicio con sesión, el formulario de email y contraseña con sus validaciones, el bloqueo mientras envía y los mensajes de error en español, la sesión persistente al reabrir, cerrar sesión desde el menú lateral, y el cierre de la base a quien no inició sesión.
---

# Spec: sesion

> Extraído automáticamente por spec-miner. Última extracción: 2026-11-06.
> Fuente: lib/features/auth/ (auth_repository.dart, auth_repository_impl.dart, login_form_cubit.dart, login_screen.dart, sesion_router.dart), lib/config/router/app_router.dart, lib/config/supabase/supabase_config.dart, lib/main.dart, lib/features/shared/widgets/side_menu.dart, supabase/migrations/20261004000000_solo_usuarios_logueados.sql
> Last verified: 2026-11-06 (commit 1d15233)

---

### Requirement: Llevar a la pantalla de ingreso a quien no inició sesión
<!-- id: sesion_router.redireccionPorSesion -->
<!-- entities: AuthRepository, Session -->
<!-- enforced: sesion_router.redireccionPorSesion(), createAppRouter() -->

Si no hay una sesión guardada en el dispositivo, la app DEBE llevar cualquier ruta (también un enlace directo a una pantalla interna) a la pantalla de ingreso; estando ya en la pantalla de ingreso sin sesión, DEBE dejarla abierta. La pantalla de ingreso muestra el ícono de la tienda, "Huantex", "Inicia sesión para continuar", los campos "Email" y "Contraseña" y el botón "Ingresar".

#### Scenario: Abrir la app sin sesión
<!-- test: test/config/router/app_router_test.dart::sin sesión abre en /login -->
<!-- test: test/features/auth/auth_test.dart::sin sesión cualquier ruta va a /login -->
- **WHEN** la app se abre sin sesión guardada
- **THEN** muestra la pantalla de ingreso en lugar del inicio

#### Scenario: Enlace directo sin sesión
<!-- test: test/config/router/app_router_test.dart::sin sesión, un deep link también termina en /login -->
- **WHEN** sin sesión se pide una ruta interna (por ejemplo, las ventas de una sucursal)
- **THEN** la app termina en la pantalla de ingreso

#### Scenario: Ya en la pantalla de ingreso
<!-- test: test/features/auth/auth_test.dart::sin sesión en /login se queda -->
- **WHEN** sin sesión la ubicación es la pantalla de ingreso
- **THEN** la app la deja abierta, sin redirigir

---

### Requirement: Volver al inicio cuando ya hay sesión
<!-- id: sesion_router.redireccionPorSesion -->
<!-- entities: AuthRepository, Session -->
<!-- enforced: sesion_router.redireccionPorSesion(), createAppRouter() -->

Con una sesión activa, pedir la pantalla de ingreso DEBE llevar al inicio (la venta de telas, `/`); cualquier otra ruta DEBE abrirse sin redirección.

#### Scenario: Ir a la pantalla de ingreso con sesión
<!-- test: test/config/router/app_router_test.dart::con sesión, ir a /login vuelve al inicio -->
<!-- test: test/features/auth/auth_test.dart::con sesión /login vuelve al inicio y el resto pasa -->
- **WHEN** hay sesión y se pide la pantalla de ingreso
- **THEN** la app muestra el inicio

#### Scenario: Navegar con sesión
<!-- test: test/config/router/app_router_test.dart::con sesión deja pasar a las rutas raíz -->
- **WHEN** hay sesión y se pide cualquier otra ruta
- **THEN** la app abre esa ruta sin redirigir

---

### Requirement: Cambiar de pantalla sola al entrar o salir de la sesión
<!-- id: AuthRepositoryImpl.cambiosDeSesion -->
<!-- entities: AuthRepository, Session -->
<!-- enforced: AuthRepositoryImpl.cambiosDeSesion(), SesionListenable.new(), createAppRouter() -->

Cada vez que la sesión empieza, se cierra o expira, la app DEBE volver a evaluar la ruta actual sin que el usuario navegue: al entrar pasa al inicio y al perder la sesión pasa a la pantalla de ingreso. La entrada después de un enlace directo lleva al inicio, no a la ruta pedida originalmente.

#### Scenario: Ingreso exitoso
<!-- test: test/config/router/app_router_test.dart::al iniciar sesión el router solo pasa al inicio -->
<!-- test: test/features/auth/presentation/sesion_router_test.dart::avisa al router en cada entrada y salida de sesión -->
- **WHEN** el usuario inicia sesión desde la pantalla de ingreso
- **THEN** la app muestra el inicio sin navegación manual

#### Scenario: La sesión expira o se cierra
<!-- test: test/config/router/app_router_test.dart::si la sesión se cae (expira) el router manda a /login -->
- **WHEN** la sesión deja de existir mientras se usa la app
- **THEN** la app muestra la pantalla de ingreso

---

### Requirement: Habilitar el ingreso solo con email y contraseña completos
<!-- id: LoginFormState.puedeEnviar -->
<!-- entities: LoginFormState -->
<!-- enforced: LoginFormState.puedeEnviar(), LoginFormCubit.onSubmit() -->

El botón "Ingresar" DEBE estar habilitado solo cuando el email, sin espacios alrededor, no está vacío, la contraseña no está vacía y no hay un ingreso en curso. Un intento de envío que no cumple esto NO DEBE consultar al servidor.

#### Scenario: Campos vacíos
<!-- test: test/features/auth/auth_test.dart::no envía con campos vacíos -->
<!-- test: test/features/auth/auth_test.dart::el botón se habilita al completar email y contraseña -->
- **WHEN** el email o la contraseña están vacíos
- **THEN** "Ingresar" está deshabilitado y enviar no consulta al servidor

#### Scenario: Email de solo espacios
<!-- test: test/features/auth/presentation/bloc/login_form_cubit_test.dart::un email de solo espacios no habilita el envío -->
- **WHEN** el email tiene solo espacios y la contraseña está escrita
- **THEN** "Ingresar" sigue deshabilitado

#### Scenario: Email sin contraseña
<!-- test: integration_test/flujos/auth.dart::exige ambos campos, rechaza credenciales malas, entra con las buenas y cierra sesión -->
- **WHEN** se escribió el email pero no la contraseña
- **THEN** "Ingresar" sigue deshabilitado

---

### Requirement: Iniciar sesión con email y contraseña
<!-- id: LoginFormCubit.onSubmit -->
<!-- entities: LoginFormState, AuthRepository -->
<!-- enforced: LoginFormCubit.onSubmit(), AuthRepositoryImpl.iniciarSesion() -->

Al tocar "Ingresar", o "Listo" en el teclado del campo de contraseña, la app DEBE autenticar contra Supabase Auth con el email sin espacios alrededor y la contraseña tal como se escribió (los espacios cuentan). Si la autenticación sale bien, el paso al inicio lo hace la redirección por sesión.

#### Scenario: Credenciales correctas
<!-- test: test/features/auth/auth_test.dart::credenciales correctas inician sesión (email sin espacios) -->
<!-- test: test/features/auth/auth_test.dart::credenciales correctas inician sesión -->
<!-- test: integration_test/flujos/auth.dart::exige ambos campos, rechaza credenciales malas, entra con las buenas y cierra sesión -->
- **WHEN** el usuario escribe un email con espacios alrededor y la contraseña correcta, y toca "Ingresar"
- **THEN** se autentica con el email sin espacios, queda una sesión y la app muestra el inicio

#### Scenario: Contraseña con espacios
<!-- test: test/features/auth/presentation/bloc/login_form_cubit_test.dart::la contraseña no se recorta (los espacios cuentan) -->
- **WHEN** la contraseña empieza o termina con espacios
- **THEN** se envía sin recortar

#### Scenario: Enviar desde el teclado
<!-- test: test/features/auth/presentation/screens/login_screen_test.dart::"Listo" en el teclado de la contraseña envía el formulario -->
- **WHEN** el usuario toca "Listo" en el teclado del campo de contraseña
- **THEN** la app intenta iniciar sesión igual que con "Ingresar"

---

### Requirement: Bloquear el formulario mientras se inicia sesión
<!-- id: LoginFormCubit.onSubmit -->
<!-- entities: LoginFormState -->
<!-- enforced: LoginFormCubit.onSubmit(), LoginFormState.puedeEnviar(), _LoginFormState.build() -->

Mientras el ingreso está en curso, los campos y el botón DEBEN quedar deshabilitados, el botón DEBE mostrar un indicador de progreso en lugar de "Ingresar" y un segundo envío NO DEBE llegar al servidor.

#### Scenario: Ingreso en curso
<!-- test: test/features/auth/presentation/screens/login_screen_test.dart::mientras inicia sesión bloquea los campos y el botón y muestra el progreso -->
- **WHEN** el usuario tocó "Ingresar" y el servidor todavía no respondió
- **THEN** campos y botón están deshabilitados y el botón muestra el progreso

#### Scenario: Doble toque
<!-- test: test/features/auth/presentation/bloc/login_form_cubit_test.dart::mientras envía no deja reenviar (doble toque) -->
- **WHEN** se intenta enviar otra vez mientras el primer ingreso sigue en curso
- **THEN** solo se hace un pedido de autenticación

---

### Requirement: Explicar en español por qué falló el ingreso
<!-- id: AuthRepositoryImpl.iniciarSesion -->
<!-- entities: AuthFallo, LoginFormState -->
<!-- enforced: AuthRepositoryImpl.iniciarSesion(), AuthRepositoryImpl.mensajeDeError(), LoginFormCubit.onSubmit() -->

Si el ingreso falla, la app DEBE quedarse en la pantalla de ingreso sin sesión, volver a habilitar el formulario y mostrar debajo de la contraseña, en color de error, un mensaje en español; NO DEBE mostrar el texto técnico de la excepción. Los mensajes de Supabase Auth se traducen sin distinguir mayúsculas.

#### Scenario: Credenciales incorrectas
<!-- test: test/features/auth/auth_test.dart::traduce los mensajes conocidos de Supabase -->
<!-- test: test/features/auth/auth_test.dart::credenciales incorrectas muestran el error en pantalla -->
<!-- test: integration_test/flujos/auth.dart::exige ambos campos, rechaza credenciales malas, entra con las buenas y cierra sesión -->
<!-- test: test/vectores/auth_errores_vectores_test.dart::credenciales inválidas -->
- **WHEN** Supabase Auth responde "invalid login credentials"
- **THEN** se muestra "Email o contraseña incorrectos"

#### Scenario: Email sin confirmar
<!-- test: test/features/auth/auth_test.dart::traduce los mensajes conocidos de Supabase -->
<!-- test: test/vectores/auth_errores_vectores_test.dart::email sin confirmar -->
- **WHEN** Supabase Auth responde "email not confirmed"
- **THEN** se muestra "El email de esta cuenta no está confirmado"

#### Scenario: Demasiados intentos
<!-- test: test/features/auth/auth_test.dart::traduce los mensajes conocidos de Supabase -->
<!-- test: test/vectores/auth_errores_vectores_test.dart::límite de pedidos -->
<!-- test: test/vectores/auth_errores_vectores_test.dart::demasiados pedidos -->
- **WHEN** el mensaje de Supabase Auth contiene "rate limit" o "too many"
- **THEN** se muestra "Demasiados intentos. Espera un momento."

#### Scenario: Otro error de autenticación
<!-- test: test/features/auth/auth_test.dart::mensaje genérico para lo desconocido -->
<!-- test: test/vectores/auth_errores_vectores_test.dart::otro error -->
- **WHEN** Supabase Auth responde con cualquier otro mensaje
- **THEN** se muestra "No se pudo iniciar sesión"

#### Scenario: Sin conexión
- **WHEN** el pedido de autenticación no llega al servidor (sin red)
- **THEN** el cliente de Auth lo informa como error de autenticación y se muestra "No se pudo iniciar sesión"

<!-- revisar: auth_repository_impl.dart:23-27 — gotrue 2.21.0 envuelve las fallas de red en AuthRetryableFetchException (subclase de AuthException), así que caen en mensajeDeError() y muestran "No se pudo iniciar sesión"; el mensaje "Sin conexión. Revisa el internet e intenta de nuevo." (rama catch (_)) solo aparece con errores que no son de Auth. Los tests de "sin conexión" usan un fake que lanza AuthFallo directo. -->

#### Scenario: Error que no viene de Supabase Auth
<!-- test: test/features/auth/auth_test.dart::sin conexión devuelve el mensaje del repositorio -->
<!-- test: test/features/auth/presentation/bloc/login_form_cubit_test.dart::un error inesperado muestra un mensaje genérico, no la excepción -->
- **WHEN** el intento falla con una excepción ajena a Supabase Auth
- **THEN** se muestra "Sin conexión. Revisa el internet e intenta de nuevo." si la produjo el acceso a Auth, o "No se pudo iniciar sesión" si es inesperada

#### Scenario: Reintentar después del error
<!-- test: test/features/auth/presentation/screens/login_screen_test.dart::sin conexión muestra el mensaje y deja reintentar -->
- **WHEN** se muestra un error de ingreso
- **THEN** el formulario vuelve a estar habilitado y se puede tocar "Ingresar" de nuevo

---

### Requirement: Borrar el mensaje de error al corregir los datos
<!-- id: LoginFormState.copyWith -->
<!-- entities: LoginFormState -->
<!-- enforced: LoginFormState.copyWith(), LoginFormCubit.onEmailChanged(), LoginFormCubit.onPasswordChanged() -->

Cualquier cambio en el email o en la contraseña DEBE quitar el mensaje de error que estaba a la vista.

#### Scenario: Escribir después de un error
<!-- test: test/features/auth/auth_test.dart::credenciales incorrectas muestran el error y escribir lo limpia -->
- **WHEN** hay un mensaje de error y el usuario modifica el email o la contraseña
- **THEN** el mensaje desaparece

---

### Requirement: Mostrar u ocultar la contraseña
<!-- id: _LoginFormState.build -->
<!-- entities: LoginFormState -->
<!-- enforced: _LoginFormState.build() -->

La contraseña DEBE escribirse oculta; un botón con forma de ojo (etiqueta "Mostrar" u "Ocultar") DEBE alternar entre verla y ocultarla.

#### Scenario: Alternar la visibilidad
<!-- test: test/features/auth/presentation/screens/login_screen_test.dart::la contraseña arranca oculta y el ojo la muestra y la oculta -->
- **WHEN** el usuario toca "Mostrar" y después "Ocultar"
- **THEN** la contraseña se ve en claro y luego vuelve a ocultarse

---

### Requirement: Conservar la sesión al reabrir la app
<!-- id: SupabaseConfig.init -->
<!-- entities: Session -->
<!-- enforced: SupabaseConfig.init(), AuthRepositoryImpl.haySesion() -->

La sesión iniciada DEBE quedar guardada en el dispositivo: al reabrir la app, o al instalar una versión nueva encima, con una sesión guardada vigente, la app DEBE abrir directamente en el inicio sin pedir ingreso. La persistencia es la que trae Supabase Auth por defecto (no hay código propio que la guarde); la sesión se restaura antes de mostrar la primera pantalla.

#### Scenario: Reabrir con sesión guardada
<!-- test: tool/prueba_actualizacion.dart -->
- **WHEN** el usuario cierra la app o la actualiza y la vuelve a abrir
- **THEN** la app abre en el inicio, sin la pantalla de ingreso

---

### Requirement: Cerrar sesión desde el menú lateral
<!-- id: SideMenu.build -->
<!-- entities: AuthRepository, Session -->
<!-- enforced: SideMenu.build(), AuthRepositoryImpl.cerrarSesion() -->

Al pie del menú lateral DEBE haber una opción "Cerrar sesión" con el email de la cuenta como subtítulo (vacío si no se conoce). Tocarla DEBE cerrar la sesión sin pedir confirmación, y la redirección por sesión DEBE llevar a la pantalla de ingreso.

#### Scenario: Ver la cuenta en el menú
<!-- test: test/features/shared/side_menu_test.dart::muestra "Cerrar sesión" con el email de la cuenta -->
- **WHEN** el usuario abre el menú lateral con sesión
- **THEN** ve "Cerrar sesión" con su email debajo

#### Scenario: Cuenta sin email
<!-- test: test/features/shared/side_menu_test.dart::sin email de cuenta el subtítulo queda vacío -->
- **WHEN** la sesión no tiene email
- **THEN** el subtítulo de "Cerrar sesión" queda vacío

#### Scenario: Cerrar sesión
<!-- test: test/features/shared/side_menu_test.dart::"Cerrar sesión" cierra la sesión de la cuenta -->
<!-- test: test/config/router/app_router_test.dart::cerrar sesión desde el menú vuelve a /login sin navegar a mano -->
<!-- test: integration_test/flujos/auth.dart::exige ambos campos, rechaza credenciales malas, entra con las buenas y cierra sesión -->
- **WHEN** el usuario toca "Cerrar sesión"
- **THEN** la sesión se cierra en el dispositivo y la app muestra la pantalla de ingreso

<!-- revisar: side_menu.dart:98 + main.dart:34 — cerrar sesión no reinicia la sección marcada del menú (MenuIndexCubit es global): al volver a entrar se abre el inicio pero el menú sigue marcando la última sección visitada. -->

---

### Invariant: La app no permite crear cuentas
<!-- entities: AuthRepository -->
<!-- enforced: AuthRepository, LoginScreen.build() -->

La app NO DEBE ofrecer registro de cuentas ni recuperación de contraseña: solo DEBE permitir ingresar con cuentas que ya existen en Supabase Auth (las crea el dueño desde el panel de Supabase). El acceso no tiene roles: todo usuario que ingresa ve y puede usar todas las pantallas.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Sin sesión la base no entrega ni acepta datos
<!-- entities: anon, authenticated -->
<!-- enforced: 20261004000000_solo_usuarios_logueados.sql:solo_logueados_<tabla>, 20261004000000_solo_usuarios_logueados.sql:REVOKE ALL ON ALL TABLES/SEQUENCES FROM anon -->
<!-- verified_by: supabase/tests/database/01_rls_y_permisos.test.sql::anon no tiene ningún privilegio sobre las tablas -->
<!-- verified_by: supabase/tests/database/01_rls_y_permisos.test.sql::anon no tiene privilegios sobre las secuencias -->
<!-- verified_by: supabase/tests/database/01_rls_y_permisos.test.sql::anon y authenticated pueden leer todas las vistas *_web -->

Sin sesión (rol `anon`) la base NO DEBE permitir leer ni escribir ninguna tabla ni secuencia; solo DEBE permitir leer las vistas públicas `*_web`. Con sesión (rol `authenticated`) las políticas `solo_logueados_*` DEBEN dar acceso total a todas las filas, sin roles.

> Last verified: 2026-11-06 (commit 1d15233)

<!-- revisar: 20261004000000_solo_usuarios_logueados.sql:40 — el REVOKE EXECUTE ... FROM anon no quita el EXECUTE que PUBLIC tiene por defecto: anon todavía puede ejecutar top_productos, resumen_ventas y resumen_ventas_apliques (fallan por falta de SELECT en las tablas). Marcado como todo() en 01_rls_y_permisos.test.sql:198. -->

<!-- uncertainty: la persistencia y el refresco de la sesión dependen del comportamiento por defecto de supabase_flutter (Supabase.initialize sin authOptions); no hay código propio que lo fije ni test unitario, solo la verificación manual de tool/prueba_actualizacion.dart. -->
<!-- uncertainty: el menú lateral general (secciones y sección marcada) no pertenece a esta capacidad; aquí solo se cubre "Cerrar sesión". -->
