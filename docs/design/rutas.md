# Rutas y navegación por URL (spec 02, paso 2)

- Spec: `specs/02-ortiz-al-centro.md` (Aprobado; PA-01…PA-05 resueltas). CA cubiertos: CA-05, CA-06, CA-07, URL desconocida y retiro del launcher (PA-05).
- Plataforma objetivo: **solo Flutter web** (Vercel; `vercel.json` ya reescribe todo a `index.html`).
- Lo marcado **«por verificar en implementación»** no se pudo confirmar al leer el código. `flutter-dev` lo comprueba antes de programar y, si no se cumple, lo avisa.

## Arquitectura y datos

### 0. Situación actual (lo que encontré en el código)

- `lib/main.dart`: `MultiProvider` (7 ViewModels) → `Consumer<AppState>` → `MaterialApp(home: ResponsiveSuiteScaffold(mobileBody: AppLauncherScreen()))`. No hay rutas con nombre ni `onGenerateRoute`.
- `lib/widgets/responsive_suite_scaffold.dart`:
  - En `< 840` devuelve el launcher.
  - En `≥ 840` muestra un sidebar con `enum SuiteModule { commandCenter, quebrado, diario, habitos, recordatorios, agente, notas }`, una barra superior (tasas, calculadora, sincronizar) y `_buildActiveView()` con un `switch`.
  - Al cambiar de módulo **no se conserva el estado**: no hay `IndexedStack`, aunque el comentario diga lo contrario.
- Launcher móvil (`lib/screens/app_launcher_screen.dart`): cada tarjeta hace `Navigator.of(context).push(CupertinoPageRoute(builder: (_) => XxxHomeScreen()))` sobre el Navigator raíz.
- **Botones «atrás» que dan por hecho que el launcher está debajo** (se rompen con el router):
  - `diario/screens/diario_home_screen.dart:170`: `Navigator.pop()`, sin condición.
  - `recordatorios/screens/reminders_home_screen.dart:142`: `Navigator.pop()`, sin condición.
  - `habitos/screens/habitos_home_screen.dart:150`: solo en móvil.
  - `quebrado/screens/dashboard_screen.dart:182-188`: `canPop ? pop : pushReplacement(AppLauncherScreen)`, en móvil. Además **importa `AppLauncherScreen`**.
- Navigator anidado: solo `quebrado/screens/market_screen.dart:37`. El resto (44 `push` en 14 archivos) usa el Navigator más cercano.
- `diario_home_screen.dart:289` usa `PopScope(canPop: activeContactId == null)`.
- **PIN/biometría no es un bloqueo de la app.** Es una confirmación por operación:
  - Se exige con `AppState.verifySecurityAuth(context, reason:)` (`app_state.dart:444`) en `add_transaction_dialog`, `pending_confirmations_dialog`, `partial_payment_dialog`, `transfer_bank_dialog`, `cross_profile_transfer_dialog`, `market_trip_screen` y `timeline_event_row`.
  - Restaurar un respaldo pide el PIN directamente (`backup_management_screen.dart:450`).
  - En web la biometría no existe: si `useBiometrics` está activo, se pide el PIN (`app_state.dart:461`).
  - Si nunca se configuró, el PIN es `'1234'` (`getSecurityPin`).
  - CA-07 introduce, por tanto, un comportamiento **nuevo**: pedir el PIN para *ver*.
- Hallazgo: en la carga desde Supabase, `_doLoadData` lee `useBiometrics` pero **no `usePinSecurity`** (`app_state.dart:205`). En web con Supabase, «PIN activado» solo sobrevive a una recarga si la biometría está activada. Va a `docs/pendientes.md` y no se arregla de paso; afecta a CA-07 (ver P-04).
- Detalles que ya existen y pueden abrirse por id:

| Registro | Vista existente | Dónde vive el dato | Búsqueda por id hoy |
| --- | --- | --- | --- |
| Movimiento | `TransactionDetailBottomSheet(transaction:)` (`quebrado/dialogs/transaction_detail_dialog.dart`), que hoy se abre con `showModalBottomSheet` desde el Historial | `AppState.transactions` (solo del **libro activo**; los demás libros están en `_cachedTransactions`, privado) | no existe; `transactions.where((t) => t.id == id)` |
| Pagos pendientes | `PendingConfirmationsBottomSheet()` (`quebrado/dialogs/pending_confirmations_dialog.dart`) | `AppState.pendingPaymentsToday` | — (sin id) |
| Entrada de diario | `openEntryReader(context, entry)` / `EntryReaderDialog(entry:, isBottomSheet:)` (`diario/dialogs/entry_reader_dialog.dart`) | `DiarioState.entries` (carga en el constructor) | no existe; `entries.where(...)` |
| Ánimo | `AnimoDashboardScreen()` (`diario/screens/animo_dashboard_screen.dart`) | `AnimoState.logs` | — (sin id) |
| Hábito | `HabitDetailCliDialog(habit:)` (`habitos/dialogs/habit_detail_cli_dialog.dart`) | `HabitosState.habits` | `_habitById` es **privado** |
| Recordatorio | **No hay vista de lectura**; solo `ReminderEditorDialog(reminder:)` | `RemindersState.allReminders` | no existe |
| Nota | `NoteReaderDialog.show(context, noteId:)` (`notas/dialogs/note_reader_dialog.dart`), que **ya acepta un id** | `NotasState.getNoteById(id)` | sí |

### 1. Decisión: `go_router` (no el `Router` nativo)

**Recomendación: `go_router`**, el paquete del equipo de Flutter (publisher flutter.dev).

- **Versión:** la mayor que resuelva `flutter pub add go_router` con Flutter 3.38.3 / Dart 3.10 (se espera 16.x o 17.x), fijada con `^` en `pubspec.yaml`.
  - Mínimo 14.x, por `StatefulShellRoute.indexedStack`, `onException`, `redirect` asíncrono y `GoRouterState.of`.
  - *Por verificar en implementación:* la versión exacta que resuelve y las notas de cambios entre mayores (desde la 15.x las rutas distinguen mayúsculas por defecto: `/Diario` caería en «no existe», lo que es aceptable).
- **URL sin `#`:** `usePathUrlStrategy()` de `package:flutter_web_plugins/url_strategy.dart`, llamado en `main()` antes de `runApp`.
  - Hay que añadir `flutter_web_plugins: sdk: flutter` a `dependencies`.
  - `vercel.json` ya cubre la recarga en rutas profundas.
- **Por qué no el `Router` nativo:** habría que escribir a mano el `RouteInformationParser`, el `RouterDelegate`, el manejo de Atrás del navegador, un Navigator por app con su estado conservado y los guards asíncronos. Son cientos de líneas propias que `go_router` ya trae probadas, y con más riesgo (R-03).
- **Coste de `go_router`:** una dependencia más, pequeña y sin código nativo.

### 2. Árbol de rutas

La fuente de los paths de cada app es `SuiteApp.route` (`lib/theme/suite_apps.dart`). Los paths de detalle se construyen con helpers, para no repetir strings en los formularios del paso 6 (aviso «Ver»).

```
StatefulShellRoute.indexedStack  (builder: SuiteShell)
├─ rama 0  /                         Inicio de Ortiz (paso 5: OrtizHomeScreen; hasta entonces AgenteHomeScreen)
├─ rama 1  /finanzas                 MainScreen
│   ├─ movimientos/:id               hoja sobre MainScreen (pestaña Historial): TransactionDetailBottomSheet
│   ├─ pagos                         hoja sobre MainScreen: PendingConfirmationsBottomSheet
│   └─ desbloquear?siguiente=…       pantalla de PIN (ver §5)
├─ rama 2  /diario                   DiarioHomeScreen
│   ├─ entradas/:id                  diálogo (≥ 768) u hoja: EntryReaderDialog(entry, isBottomSheet)
│   └─ animo                         página completa: AnimoDashboardScreen()
├─ rama 3  /habitos                  HabitosHomeScreen
│   └─ :id                           diálogo: HabitDetailCliDialog(habit)
├─ rama 4  /recordatorios            RemindersHomeScreen
│   └─ :id                           ver «Recordatorio» abajo (P-02)
└─ rama 5  /notas                    NotasHomeScreen
    └─ :id                           diálogo: NoteReaderDialog(noteId: id)
onException → go('/') + aviso «Esa página no existe»
```

Helpers propuestos, en `lib/widgets/suite_router.dart`:

```dart
abstract final class SuiteRoutes {
  static const home = '/';
  static String movimiento(String id) => '${SuiteApp.finanzas.route}/movimientos/${Uri.encodeComponent(id)}';
  static String get pagos => '${SuiteApp.finanzas.route}/pagos';
  static String entrada(String id) => '${SuiteApp.diario.route}/entradas/${Uri.encodeComponent(id)}';
  static String get animo => '${SuiteApp.diario.route}/animo';
  static String habito(String id) => '${SuiteApp.habitos.route}/${Uri.encodeComponent(id)}';
  static String recordatorio(String id) => '${SuiteApp.recordatorios.route}/${Uri.encodeComponent(id)}';
  static String nota(String id) => '${SuiteApp.notas.route}/${Uri.encodeComponent(id)}';
}
```

**Detalles como páginas del router (diálogo u hoja ligados a la URL).** Cada ruta de detalle usa un `pageBuilder` que devuelve una `Page` cuya `createRoute` crea un `DialogRoute` o un `ModalBottomSheetRoute`: `SuiteDialogPage` y `SuiteSheetPage`, en `lib/widgets/suite_route_pages.dart`. Así:

- Debajo se ve la pantalla de la app (la ruta padre).
- Cerrar el diálogo hace `pop`, y `go_router` deja la URL en el padre (`/finanzas`).
- El Atrás del navegador cierra el detalle.
- En escritorio, si `showResponsiveSheet` abre el panel lateral derecho, `SuiteSheetPage` debe reproducir ese mismo comportamiento como `Page`.
  - *Por verificar en implementación:* leer `lib/widgets/responsive_sheet_helper.dart` y, si su ruta no se puede reutilizar, extraer de ahí la construcción del `Route` en vez de copiarla.

**Carga por id (`SuiteRecordLoader`).** Al entrar en frío (pegar la URL) los ViewModels pueden no haber cargado todavía. La página de detalle:

1. Espera la carga del módulo:
   - `AppState.loadData()`, que es idempotente y devuelve el futuro en curso.
   - En el resto, `isLoading == false` escuchando el `ChangeNotifier`.
   - Mientras tanto, un indicador del design system.
2. Busca el registro con `SuiteRecordLookup` (`lib/services/suite_record_lookup.dart`), un servicio puro con funciones `find(list, id)` sobre los getters públicos que ya existen. Así **no se tocan los ViewModels** ni se hace pública `_habitById`.
3. Si no lo encuentra: `go(<ruta de la app>)` + aviso «Esa página no existe» (P-03).
   - `AppState.loadData()` captura sus errores internamente, así que tras el `await` se busca igualmente.
   - Si Supabase no está configurado, cada módulo usa su respaldo actual y la búsqueda se hace sobre esos datos.

Particularidades por ruta:

- **`/finanzas/movimientos/:id`:** antes de abrir la hoja, `appState.setTabIndex(2)` (Historial), para que debajo se vea la lista. Solo busca en el libro activo (P-01).
- **`/finanzas/pagos`:** `MainScreen.initState` ya abre `PendingConfirmationsBottomSheet` si hay pagos hoy, y se abriría dos veces. Para evitarlo, `MainScreen` no lo autoabre si `GoRouterState.of(context).uri.path == SuiteRoutes.pagos`.
  - *Por verificar en implementación:* qué muestra la hoja cuando la lista está vacía.
- **`/diario/animo`:** «Ver» tras registrar ánimo lleva al tablero (no hay id de log). Es una página normal, no una hoja.
- **`/recordatorios/:id`:** no existe vista de lectura. Propuesta mínima, sin reglas nuevas: abrir `RemindersHomeScreen` y encima `ReminderEditorDialog(reminder: r)`, que es lo mismo que hace hoy la app al tocar un recordatorio (*por verificar en implementación*). La alternativa, solo resaltar el registro en la lista, la decide la persona (P-02).

### 3. Shell responsive

`StatefulShellRoute.indexedStack` con `builder: (context, state, navigationShell) => SuiteShell(navigationShell: navigationShell)`. `SuiteShell` sustituye a `ResponsiveSuiteScaffold`; se puede renombrar el archivo en el paso 5.

- **`< 840` (`!ResponsiveBreakpoints.isDesktop`):**
  - `Scaffold(key: shellScaffoldKey, drawer: SuiteDrawer(...), body: navigationShell)`.
  - El shell **no** pinta barra superior: la de `/` la pinta `OrtizHomeScreen` (☰, cara + «Ortiz», nueva conversación), y cada app conserva su `AppBar`.
  - El botón «atrás» de cada app se sustituye por un ☰ que abre el drawer del shell (`SuiteMenuButton`, que usa `shellScaffoldKey.currentState?.openDrawer()` o un `SuiteShellScope` heredado).
- **`≥ 840`:** `Row(SuiteRail(210/240 px), VerticalDivider, Expanded(navigationShell))`.
  - El **panel derecho solo existe en el inicio**: es parte de `OrtizHomeScreen`, no del shell.
  - La barra superior actual del escritorio (tasas, calculadora, sincronizar) desaparece con el shell nuevo (P-05).
- **Navegar a una app:** `navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex)`. Volver a tocar la app activa la lleva a su raíz.
  - Desde el aviso «Ver» y la paleta: `context.go(SuiteRoutes.x(id))`.
- **Estado:**
  - **Se conserva** el estado de cada app al cambiar entre ellas: cada rama tiene su Navigator dentro de un `IndexedStack`, con scroll, pestañas y lo que se haya apilado dentro. Hoy en escritorio se pierde, así que esto es una mejora.
  - Las ramas se construyen la primera vez que se visitan (sin `preload`), así que `MainScreen.initState` (refresco de tasas y hoja de pendientes) sigue ocurriendo solo al entrar en Finanzas.
  - Los ViewModels siguen siendo globales (`MultiProvider` por encima de `MaterialApp.router`).
- **`main.dart`:**
  - `MaterialApp.router(routerConfig: _router, scaffoldMessengerKey: suiteMessengerKey, ...)`.
  - El `GoRouter` se crea **una sola vez** (en el `State` de un `StatefulWidget` raíz, con acceso a `context.read<AppState>()`), nunca dentro del `builder` del `Consumer<AppState>`, que se reconstruye con cada cambio de `AppState`.
  - *Por verificar en implementación:* si el `Consumer<AppState>` sigue haciendo falta (el color del libro se aplica con `AppColors.updateThemeColor`, que es estático).

### 4. Compatibilidad con la navegación interna

- **`Navigator.push` internos** (p. ej. `diario_home_screen` → `AnimoDashboardScreen`, `ContactDetailScreen`, ajustes de Quebrado): `Navigator.of(context)` encuentra el Navigator de la **rama**, y la ruta pageless se apila dentro del área de contenido. El riel y el drawer siguen visibles; hoy en móvil tapaba toda la pantalla.
  - Si alguna pantalla debe tapar el shell (p. ej. `NoteEditorScreen` a pantalla completa en el teléfono, PA-04), usa `Navigator.of(context, rootNavigator: true)`.
  - *Por verificar en implementación:* que `NoteEditorScreen.open` y los editores a pantalla completa lo hagan, o decidirlo en el paso 6.
- **`showDialog`:** usa el Navigator raíz por defecto (`useRootNavigator: true`), así que no cambia nada.
- **`showModalBottomSheet`:** por defecto usa el Navigator más cercano (el de la rama), por lo que la hoja queda dentro del área de contenido. Es aceptable y ocurre igual en escritorio hoy.
  - Las acciones rápidas del paso 4 que se abren desde el riel o el drawer usan el `context` del shell, cuyo Navigator más cercano es el raíz.
- **`MarketScreen`:** su Navigator anidado queda dentro de la rama de Finanzas, y no cambia nada.
- **Rutas pageless y URL:** las pantallas que se apilan con `push` no cambian la URL. Si se navega con `go` a otra URL de la misma rama, `go_router` retira esas rutas de encima. Es el comportamiento esperado.
- **Botones «atrás» rotos** (§0): se sustituyen por `SuiteMenuButton` en `dashboard_screen.dart`, `diario_home_screen.dart`, `reminders_home_screen.dart` y `habitos_home_screen.dart`.
  - Un `Navigator.pop()` en la raíz de una rama dejaría la rama sin páginas: es un error.
  - `dashboard_screen.dart` deja de importar `AppLauncherScreen`.
- **Atrás del navegador:** cada `go` y `goBranch` crea una entrada en el historial del navegador, así que Atrás vuelve a la URL anterior (CA-06). Si cierra una hoja de detalle, la URL vuelve al padre.
  - Los `PopScope` (Diario) siguen funcionando para el botón Atrás del sistema; en web el Atrás del navegador es un cambio de URL y no pasa por `PopScope`. No cambia respecto a hoy.
- **URL desconocida:** `onException: (context, state, router) => router.go('/', extra: const SuiteNotice.paginaNoExiste())`.
  - El shell muestra el aviso «Esa página no existe» con `suiteMessengerKey`, una sola vez.
  - Un id inexistente en una ruta válida sigue la misma regla, pero redirige a la raíz de su app (§2, P-03).

### 5. PIN o biometría con deep links (CA-07)

> **Sustituido el 2026-11-18** por el PIN una vez al día al entrar a la app (§10, P-04 revisada). Lo de abajo es el diseño original, solo como historia.

- **Mecanismo:**
  - `redirect` asíncrono en las rutas protegidas de la rama Finanzas: `movimientos/:id` y `pagos`; si se amplía, P-04.
  - El guard hace `await appState.loadData()` para tener los flags reales (hoy, al entrar en frío, valen `false` hasta que termina la carga).
  - Se exige el PIN si `usePinSecurity || useBiometrics` y la sesión no está desbloqueada.
  - En ese caso redirige a `/finanzas/desbloquear?siguiente=<path codificado>`.
- **Pantalla `desbloquear`:**
  - Muestra `MainScreen` vacía o un fondo neutro y, al primer frame, llama a `appState.verifySecurityAuth(context, reason: 'Confirma tu identidad para ver tus finanzas')`. Reutiliza `PinVerificationDialog` y la biometría donde exista.
  - Si se confirma: `SuiteLock.unlock()` y `go(siguiente)`.
  - Si se cancela: `go(SuiteApp.finanzas.route)` (P-04).
  - `siguiente` solo se acepta si empieza por `/finanzas/` y no es `desbloquear` (evita redirecciones abiertas y bucles).
- **`SuiteLock`:** un `ChangeNotifier` pequeño en memoria con `isUnlocked` y `unlock()`. **No persiste**: al recargar la pestaña se vuelve a pedir. Va en `lib/services/suite_lock.dart`, con test.
  - Se proporciona en `MultiProvider` y se pasa como `refreshListenable` del router.
  - Propuesta: marcarlo desbloqueado también cuando un formulario ya pidió el PIN al guardar (registrar gasto). Así «Ver» tras guardar no pide el PIN otra vez. Se decide en P-04.
- **Límite de seguridad, que debe constar:** el PIN es una barrera de interfaz, no de datos. Los datos siguen accesibles con la anon key (deuda conocida en `docs/pendientes.md`). Además, el PIN por defecto es `'1234'` si nunca se creó uno. Lo revisa `security-auditor`.

### 6. Retiro del launcher (PA-05, sin interruptor)

Se hace cuando `OrtizHomeScreen`, el drawer y el riel ya existen (después de los pasos 4–5).

- **Se borran:**
  - `lib/screens/app_launcher_screen.dart` (1344 líneas)
  - `lib/screens/launcher_action_hub_view.dart` (1369)
  - `lib/widgets/desktop_command_center_view.dart` (809)
  - El `enum SuiteModule` y `_buildActiveView` de `responsive_suite_scaffold.dart`, que el shell sustituye.
- **Referencias en `lib/`:**
  - `main.dart:10-11,88-89`.
  - `quebrado/screens/dashboard_screen.dart:24,187`.
  - Verificar con grep que no queda ninguna otra.
- **Tests:**
  - `test/launcher_action_hub_view_test.dart`: se borra entero, porque prueba código que deja de existir. Borrarlo es una consecuencia directa de PA-05, no saltarse la regla de «no borrar tests». Que la persona lo confirme.
  - `test/reminders_pinned_banner_and_sync_test.dart:167-…`: se quita solo el `testWidgets('AppLauncherScreen displays sync button…')` y su import (línea 12). Se mantienen los tests de recordatorios fijados.
  - `test/responsive_suite_test.dart`: los tests de breakpoints (l. 37-68) se quedan; los de l. 70-117 (`ResponsiveSuiteScaffold` / `DesktopCommandCenterView`) se reescriben para `SuiteShell` (drawer en compact, riel en `≥ 840`).
  - `test/contract/no_hardcoded_styles_test.dart:29-31`: se quitan las 3 exclusiones. La lista solo se reduce, que es lo permitido.
  - `test/all_imports_test.dart`: `./tool/generate_all_imports_test.sh`.
  - `.claude/known-failures`: *por verificar en implementación* si alguno de sus tests está en los archivos borrados. Si lo está, se quita de la lista, que solo baja.

### 7. Datos, respaldos y agente

- **Datos:** no hay tablas, columnas, RLS ni migraciones nuevas. SQLite no cambia.
- **Respaldos:** `BackupService` e `import_quebrado_backup` no cambian.
- **Agente (RAG):** no expone datos nuevos.
  - La spec 03 podrá usar `SuiteRoutes` para enlazar registros desde el chat. No se hace aquí.

### 8. Plan de implementación (`flutter-dev`, salvo indicación)

| Paso | Qué | Archivos | Verificación |
| --- | --- | --- | --- |
| 3a | Dependencias y árbol de rutas con las pantallas actuales (rama `/` = `AgenteHomeScreen` provisional), `SuiteRoutes`, `onException` | `pubspec.yaml`, `lib/widgets/suite_router.dart`, `test/widgets/suite_router_test.dart` | test: cada path de app resuelve su pantalla; `/xyz` termina en `/` con el aviso |
| 3b | `MaterialApp.router` + `usePathUrlStrategy` + messenger; shell provisional con `StatefulNavigationShell` (sidebar actual mapeado a ramas; drawer simple en compact) | `lib/main.dart`, `lib/widgets/responsive_suite_scaffold.dart`, `test/responsive_suite_test.dart` | tests compact/≥ 840; el estado de la rama se conserva al volver (p. ej. la pestaña de Diario) |
| 3c | Sustituir los «atrás» rotos por `SuiteMenuButton` (1/2) | `lib/widgets/suite_menu_button.dart`, `quebrado/screens/dashboard_screen.dart`, `diario/screens/diario_home_screen.dart` | test de widget: ☰ abre el drawer; ya no se importa `AppLauncherScreen` en el dashboard |
| 3d | Lo mismo (2/2) | `recordatorios/screens/reminders_home_screen.dart`, `habitos/screens/habitos_home_screen.dart`, test de `suite_menu_button` | tests de widget en compact |
| 3e | Páginas de diálogo u hoja ligadas a la ruta + carga por id | `lib/widgets/suite_route_pages.dart`, `lib/services/suite_record_lookup.dart`, `test/services/suite_record_lookup_test.dart` | test: encuentra el registro, `null` si no existe, sin datos reales |
| 3f | Detalles de Finanzas y Diario (`movimientos/:id`, `pagos`, `entradas/:id`, `animo`) + no duplicar la hoja de pendientes | `suite_router.dart`, `quebrado/screens/main_screen.dart`, `suite_router_test.dart` | CA-05 (con `AppState` falso); id inexistente → `/finanzas` + aviso; cerrar la hoja → URL `/finanzas` |
| 3g | Detalles de Hábitos, Recordatorios y Notas (según P-02) | `suite_router.dart`, `suite_router_test.dart` | tests por ruta |
| 3h | PIN con deep links | `lib/services/suite_lock.dart`, `suite_router.dart` (redirect + `desbloquear`), `test/services/suite_lock_test.dart` (+ caso en `suite_router_test.dart`) | CA-07: PIN activado → primero el PIN y luego el movimiento; cancelar → `/finanzas`; `siguiente` externo rechazado |
| 3i | Retiro del launcher (1/2), tras los pasos 4–5 | borrar `launcher_action_hub_view.dart`, `desktop_command_center_view.dart`, `test/launcher_action_hub_view_test.dart` | `flutter analyze` sin errores |
| 3j | Retiro del launcher (2/2) | borrar `app_launcher_screen.dart`; editar `reminders_pinned_banner_and_sync_test.dart`, `contract/no_hardcoded_styles_test.dart`; regenerar `all_imports_test.dart` | CA-01 («no aparece el launcher»), CA-13 |
| — | Revisión de seguridad del bloqueo por PIN y del PIN por defecto | — | `security-auditor` (solo informa) |

`test-engineer` puede escribir los tests de 3a, 3f y 3h en paralelo con `flutter-dev`. En los tests de rutas, el router se monta con ViewModels falsos o inyectados: ningún test toca Supabase.

### 9. Riesgos

- **R-03 (spec):** cambiar `home:` por el router afecta a toda la navegación. Se mitiga con los pasos 3c/3d y los tests por app.
- **Rutas de detalle como `Page` de diálogo u hoja:** si `showResponsiveSheet` no se puede expresar como `Page`, se usa como respaldo un `postFrameCallback` que abre la hoja con `showResponsiveSheet` y hace `context.go(padre)` al cerrarla. Es menos limpio: Atrás no cierra la hoja.
- **Redirect asíncrono que espera `loadData()`:** si Supabase tarda, la entrada en frío a `/finanzas/movimientos/…` muestra la carga más tiempo. Se acepta.
- **Ramas lazy en `IndexedStack`:** se conservan en memoria todas las apps visitadas. Con 6 ramas es aceptable.

### 10. Preguntas abiertas (para la persona)

**Resueltas por la persona el 2026-11-17** (prevalecen sobre las propuestas de abajo):
- **P-01 / P-03:** movimiento de **otro libro** → aviso «Ese movimiento está en el libro X» y **no** se cambia de libro. Registro **inexistente** → aviso «No encontré ese registro» y se abre la raíz de su app. (Una ruta desconocida sigue siendo «Esa página no existe» → `/`.)
- **P-02:** `/recordatorios/<id>` abre Recordatorios con ese recordatorio **resaltado y visible** en la lista (no abre el editor).
- ~~**P-04:** el PIN/biometría se pide al entrar a Finanzas, una vez por sesión de la pestaña; cancelar → `/`.~~ **Revisada por la persona el 2026-11-18** tras la auditoría `docs/security/2026-11-18-spec-02-pin.md`: «el PIN se solicita **una vez al día al entrar en la app**; una vez ingresado se puede hacer todo tipo de operaciones». Vale también para las acciones rápidas (A3) y para Ortiz (A4). Implementación:
  - Candado global en `/desbloquear?siguiente=<ruta>`, fuera del shell: ni el chat ni ninguna app se construyen antes del PIN. Cancelar deja la app bloqueada con un botón «Desbloquear».
  - `SuiteLock` recuerda la fecha del último desbloqueo (`localStorage` en web) y el último valor de «seguridad activada». Recargar el mismo día no vuelve a pedirlo; al día siguiente, sí (en la siguiente navegación).
  - Tras desbloquear, `AppState.verifySecurityAuth` devuelve `true` sin diálogo (`isSessionUnlocked`).
  - Cierra ante la duda (A1): si los ajustes no se pudieron leer, se usa el último valor conocido. La primera vez en un navegador, el router espera a `loadData()`.
  - Límite de 5 intentos y 30 s de espera (`PinAttemptLimiter`, A6); título «Desbloquear» (A8).
  - `siguiente` acepta cualquier ruta interna (empieza por una sola `/`, sin esquema ni dominio, y no es `/desbloquear`); si no, `/`.
  - Se **corrige** el bug de `usePinSecurity` no cargado desde Supabase.
- **P-05:** calculadora y «Sincronizar» van al **pie del riel y del menú ☰**; las tasas del día, a la barra de Finanzas y a la paleta `⌘K` («Tasas del día»).
- **Tests del launcher:** borrar `test/launcher_action_hub_view_test.dart` y el test de `AppLauncherScreen` es consecuencia directa de PA-05 (la persona eligió borrar el launcher sin interruptor).

- **P-01** Si el movimiento de `/finanzas/movimientos/<id>` está en **otro libro** (no el activo): ¿se cambia de libro automáticamente, se avisa «Ese movimiento está en el libro X», o se trata como inexistente? Propuesta: tratarlo como inexistente hasta que se decida.
- **P-02** `/recordatorios/<id>`: no hay vista de lectura. ¿Abrir el editor con el recordatorio (como al tocarlo hoy), o solo abrir Recordatorios y resaltarlo?
- **P-03** Si la URL es válida pero el registro no existe (borrado o id mal escrito), ¿vale el mismo aviso «Esa página no existe» llevando a la raíz de la app? ¿O un texto propio, como «Ese registro ya no existe»?
- **P-04** Alcance del PIN al *ver* (CA-07 solo cubre el deep link al movimiento):
  - (a) ¿Se protegen solo `movimientos/:id` y `pagos`, o toda `/finanzas`?
  - (b) ¿Se pide también al navegar dentro de la app, o solo al entrar por URL?
  - (c) ¿Cuánto dura el desbloqueo: la sesión de la pestaña?
  - (d) ¿Guardar un gasto con PIN cuenta como desbloqueo para «Ver»?
  - (e) Al cancelar, ¿`/finanzas` o `/`?
  - Además: ¿se corrige primero el bug de `usePinSecurity` no cargado desde Supabase? Sin eso, en web CA-07 solo se cumple con la biometría activada.
- **P-05** La barra superior de escritorio actual (ticker de tasas, calculadora, «Sincronizar todos los datos») desaparece con el shell nuevo. ¿Se pierde, se mueve al riel o al panel derecho, o pasa a acciones rápidas? La ubicación la decide `ui-ux-designer`.

## UI/UX

_Pendiente (`ui-ux-designer`)._
