## MODIFIED Requirements

### Requirement: Ver los colores de una tela
<!-- id: TelasDatasourceImpl.getColoresTela -->
<!-- entities: ColorItem, colores, tela_colores -->
<!-- enforced: TelasDatasourceImpl.getColoresTela(), TelaColoresCubit.load(), TelaColoresScreen.build(), ProductoColoresList.build() -->

La pantalla de colores de una tela DEBE titularse con el nombre de la tela ("Colores de la tela" si no se conoce) y listar bajo "Colores" todos los colores activos, ordenados por nombre de la A a la Z sin distinguir mayúsculas, cada uno con su muestra redonda, su nombre y un interruptor encendido si existe un vínculo con `activo = true` en `tela_colores` para esa tela. Los colores dados de baja NO DEBEN aparecer. Mientras carga muestra un indicador de progreso; si la carga falla la lista queda vacía, sin aviso.

#### Scenario: Colores de la tela
<!-- test: test/features/telas/presentation/screens/tela_colores_screen_test.dart::el título es el nombre de la tela y hay un switch por color -->
<!-- test: test/features/telas/presentation/screens/tela_colores_screen_test.dart::cada color muestra su muestra con el hex -->
- **WHEN** se abren los colores de una tela
- **THEN** el título es el nombre de la tela y hay un interruptor por color activo, encendido en los vinculados

#### Scenario: Orden de los colores
<!-- test: test/features/telas/infrastructure/datasources/telas_datasource_impl_test.dart::colores de la tela > getColoresTela los trae por nombre, de la A a la Z sin distinguir mayúsculas -->
<!-- test: test/features/telas/infrastructure/datasources/telas_datasource_impl_test.dart::colores de la tela > la pantalla muestra los interruptores en ese orden -->
- **WHEN** se abren los colores de una tela y los colores activos son "Rojo", "azul" y "Verde"
- **THEN** se listan "azul", "Rojo" y "Verde": por nombre de la A a la Z, sin distinguir mayúsculas

#### Scenario: Nombre desconocido
<!-- test: test/features/telas/presentation/screens/tela_colores_screen_test.dart::sin nombre de tela usa el título genérico -->
- **WHEN** no se pudo obtener el nombre de la tela
- **THEN** el título es "Colores de la tela"
