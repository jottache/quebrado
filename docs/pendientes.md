# Pendientes

> Problemas encontrados que todavía no se arreglaron. Nada se pierde: lo que aparece fuera del cambio en curso se anota aquí en vez de arreglarse "de paso". Al resolver uno, se mueve a "Resueltos" con fecha y PR.
> Severidad: **crítica** / **alta** / **media** / **baja**.

## Abiertos

### Seguridad y datos
| # | Severidad | Problema | Evidencia | Propuesta |
| --- | --- | --- | --- | --- |
| P-01 | crítica | Políticas RLS permisivas (`USING (true) WITH CHECK (true)`) en casi todas las tablas y la app usa solo la anon key, sin login: cualquiera con la URL y la anon key (públicas en el build web) puede leer y escribir finanzas, diario, ánimo, contactos, etc. | `supabase/001_quebrado_schema.sql:298`, `004`, `005`, `006`, `007`, `013` | Decidir modelo de auth (p. ej. login de Supabase) y políticas por `auth.uid()`; spec propia. |
| P-02 | alta | La clave de Gemini se carga desde `.env`, que está declarado como asset en `pubspec.yaml` y además se inyecta con `--dart-define` en `build.sh`: queda pública en el build web. | `quebrado-app-flutter/pubspec.yaml` (assets `.env`), `build.sh`, `lib/agente/services/gemini_config.dart` | Llamar a Gemini desde un backend (Edge Function) o restringir la clave por dominio/API. |
| P-03 | media | `import_quebrado_backup` tiene `GRANT EXECUTE` a `anon`. | `supabase/003_import_backup_rpc.sql:533` | Revisar junto con P-01. |

### Tests
| # | Severidad | Problema | Evidencia | Propuesta |
| --- | --- | --- | --- | --- |
| P-10 | media | 5 tests en rojo antes de implantar el sistema agéntico (4 desde el 2026-11-17: el de portapapeles del Diario ya pasa); están congelados en `.claude/known-failures` (la lista solo baja). | `.claude/known-failures` (causa de cada uno en su comentario) | Arreglarlos uno a uno y quitarlos de la lista. |
| P-11 | baja | Los servicios de Supabase son singletons; solo `DiarioSupabaseService`, `AnimoSupabaseService` y `MediaStorageService` tienen `forTesting()` para usarlos con `FakeSupabase`. Notas, hábitos, recordatorios, agente y `SupabaseService` (finanzas) no. | `lib/*/services/*_supabase_service.dart` | Al tocar uno de esos servicios por una spec, añadirle `forTesting()` o cliente inyectable. |
| P-12 | baja | Scripts que reescriben código fuera del flujo de edición (`strip_consts.py`, `fix_consts.py`) y salidas de analyzer sueltas en la carpeta de la app. | `quebrado-app-flutter/*.py`, `analyzer_output*.txt` | Borrarlos si ya no se usan. |
| P-13 | baja | `analysis_options.yaml` desactiva muchos lints (`use_build_context_synchronously`, `unused_*`, etc.). | `quebrado-app-flutter/analysis_options.yaml` | Reactivarlos de a uno con su limpieza. |
| P-14 | media | La SQLite de tests (`DatabaseHelper`) es un archivo fijo que persiste entre ejecuciones (`.dart_tool/sqflite_common_ffi/databases/`, 22 bases acumuladas) y la comparten archivos que corren en paralelo: causa de fallos como el de `mobile_payment_recipient_test`. | `lib/quebrado/services/db_helper.dart` | Ruta de DB inyectable/en memoria para tests. |
| P-15 | media | `DATABASE_MODELS.md` no documenta 8 tablas que la app usa (`chat_artifacts`, `chat_messages`, `chat_prompts`, `chat_sessions`, `market_shopping_list_items`, `mood_logs`, `mood_tags`, `roles`) y llama `user_life_roles` a la tabla que en la migración 011 y en la app es `roles`. Congeladas como deuda en el test de contrato. | `test/contract/supabase_contract_test.dart` | Documentarlas y vaciar la lista de deuda. |
| P-16 | baja | La cobertura medida varía ~4 líneas entre ejecuciones y el margen sobre el umbral (31,3 %) es de ~13 líneas. | `.claude/coverage-threshold` | Subir el umbral solo con margen tras añadir tests. |
| P-17 | baja | 2 tests omitidos (`skip`) preexistentes, congelados en `.claude/known-skips` (la lista solo baja). | `test/manual_income_savings_test.dart:80`, `:123` | Reactivarlos o justificar su borrado con la persona. |

### Sistema agéntico
| # | Severidad | Problema | Propuesta |
| --- | --- | --- | --- |
| P-18 | baja | `guard-bash` no bloquea `git checkout -- <código>`, `git restore` ni `git stash` sobre código, aunque la skill `testing` prohíbe restaurar así tras una mutación. | Añadir casos al guard (primero en `guard-bash.test.py`). |
| P-19 | baja | Ningún hook impide editar una migración ya aplicada (la regla de `CLAUDE.md` §4 solo la vigila el `revisor`). | Valorar un guard que avise al editar `supabase/NNN_*.sql` ya commiteadas. |
| P-25 | baja | `FakeSupabase` no permite stubs de auth, storage ni functions (cualquier petición de ese tipo cuenta como "sin stub") y no detecta stubs que nunca se usaron. El test de contrato no ve `storage\n.from(...)` partido en varias líneas (daría un rojo falso) y cuenta como "documentada" cualquier palabra entre comillas invertidas de `DATABASE_MODELS.md`. | Ampliar los helpers cuando una spec lo necesite. |
| P-26 | baja | La huella de la puerta no incluye `.env`, `assets/` ni la versión de Flutter (hoy ningún test los lee). | Añadirlos si un test empieza a depender de ellos. |

### Diseño (detalle en `docs/design-system.md` §7)
| # | Severidad | Problema | Propuesta |
| --- | --- | --- | --- |
| P-20 | media | Valores literales en pantallas en vez de tokens (≈454 `Color(0x…)`, ≈1.856 `Colors.*`, ≈1.840 `fontSize`, ≈1.315 `EdgeInsets`); no hay escala tipográfica. | Crear tokens de tipografía/espaciado/radio y migrar por módulo con spec. |
| P-22 | alta | Accesibilidad: sin `Semantics`/`semanticLabel`; varios colores de texto no cumplen AA; objetivos táctiles < 48. | Spec de accesibilidad. |
| P-23 | media | `ResponsiveBreakpoints.isMedium` e `isDesktop` se solapan entre 840 y 1199; entre 600 y 839 se usa layout móvil. | Definir clases de ventana sin solape. |
| P-24 | media | 63 `showModalBottomSheet` y 95 `showDialog` no pasan por `showResponsiveSheet`; SnackBars sin helper común (algunos muestran `$e`); montos sin separador de miles. | Helpers comunes de feedback y formato de montos. |
| P-27 | alta | Transición del tema oscuro (spec 01, R-01) en el Agente: la burbuja del bot es `Colors.white` (`agente/widgets/chat_message_bubble.dart:84`) con texto `AgenteColors.botText` = `fg` (claro sobre blanco), y hay literales claros (`Colors.white`, `Color(0x…)`) en `agente/dialogs/agente_settings_dialog.dart` (p. ej. `:219`, opción no seleccionada en `Colors.white`) y `agente/screens/agente_home_screen.dart`. | A resolver en spec 05: `AgenteColors.botBubble` y tokens. |
| P-28 | alta | Transición (R-01): estilo `code` en línea de `rich_editor/rich_document_editor.dart:188` (`0xFFF1F5F9` + `0xFFBE185D`), claro. (El bloque de código de `custom_blocks.dart` ya se corrigió en el cierre de la spec 01.) | A resolver en spec 05: `surface`/`surfaceHigh` + `line`, texto `fg`. |
| P-29 | alta | Transición (R-01): pantallas con `Colors.white` como texto o icono sobre `AppColors.primary`/`secondary`, que ahora son el coral claro `accent` (blanco sobre coral < 3:1). | A resolver en spec 05: usar `onAccent` (o los botones del tema). |
| P-30 | alta | Transición (R-01): Notas usa `NotasColors.primary` (crema) como fondo de botones y FAB (p. ej. `notas/screens/notas_home_screen.dart:62`), con posible texto blanco encima. | A resolver en spec 05: acción principal en `accent` del tema; crema solo para señalar la app; texto `onAccent`. |
| P-32 | media | Transición (R-01): `DiarioColors.primaryDark` se usa fuera del Diario (`screens/launcher_action_hub_view.dart:498`, `:803`, `:1259`; `widgets/desktop_command_center_view.dart:69`) y ahora sale rosa (antes verde de la suite). | A resolver en spec 05 (o en la 02, que rehace inicio): `accent` o `SuiteApp` según lo que señale. |
| P-33 | baja | Transición (R-01): `withOpacity` sobre tintes que ya son translúcidos (`DiarioColors.primaryLight`/`NotasColors.primaryLight` = alpha 16 %) en `diario/widgets/mention_text_field.dart:38`, `:44`, `:220`, `:229`: la mención queda casi invisible. | A resolver en spec 05: usar el tinte tal cual, con `withValues` si hace falta. |
| P-34 | baja | Transición (R-01): literales sueltos: en `quebrado/widgets/dashboard_charts_card.dart` el tooltip usa `Colors.blueGrey[900]`/`Colors.white`, `withOpacity` y tamaños 8,5/9/10 (las series ya usan `income`/`expense` desde la spec 01); `fontFamily: 'monospace'` en `quebrado/screens/settings_screen.dart:980`, `rich_editor/rich_document_editor.dart:188` y `recordatorios/dialogs/covey_guide_dialog.dart:1156`. | A resolver en spec 05: `OrtizPalette.warn` (o token de gráfico) y `OrtizType.fontMono`. |
| P-36 | alta | Transición (R-01): texto de las clases de color (`textPrimary` = `fg`, ≈475 usos) sobre contenedores blancos literales (≈295): claro sobre blanco (1,19:1). P. ej. título del AppBar del Diario (`diario/screens/diario_home_screen.dart:156`), chips de filtro, títulos del command center, título de conversación del Agente (`agente/screens/agente_home_screen.dart:231`). Encontrado en la revisión visual de la spec 01. | Spec 05: quitar los fondos blancos literales (sin tarjetas). |
| P-37 | alta | Transición (R-01): texto oscuro literal (≈307 `Colors.black*`, `grey[700-900]`, `0xFF1F2937`…) sobre fondos que ahora son oscuros: «OrtizApp»/«Suite de Apps» del launcher (`screens/app_launcher_screen.dart:282`), paneles de cifras del launcher, «Ingreso / Compra-Venta / Gasto» (`quebrado/screens/dashboard_screen.dart:1383`); también dentro de diálogos y hojas del tema. | Spec 05: texto con `fg`/`muted`. |
| P-38 | alta | Transición (R-01): texto blanco sobre los colores de app de Diario, Hábitos y Recordatorios (≈2,3:1; ≈44 `backgroundColor: XColors.primary`), p. ej. «Crear Primera Nota» (`diario/widgets/personal_notes_view.dart:308`) y el FAB «Nueva Nota». Complementa P-29 (AppColors) y P-30 (Notas). | Spec 05: texto `onAccent` (≈8:1). |
| P-39 | media | Pastilla de moneda EUR `#2563EB` (`quebrado/widgets/currency_pill.dart`) da 3,71:1 sobre `bg`: no llega a AA como texto. | Spec 05: recalibrar los colores de moneda para fondo oscuro. |
| P-35 | baja | Transición (R-01): `screens/app_launcher_screen.dart:4` importa `google_fonts` sin usarlo; es el último import del paquete en `lib/` (las fuentes ya vienen de assets). | A resolver en spec 05 (o 02): quitar el import y valorar quitar la dependencia. |

## Resueltos
| # | Fecha | Cómo |
| --- | --- | --- |
| P-31 | 2026-11-17 | Spec 01 (cierre): el panel lateral de escritorio de `showResponsiveSheet` usa `OrtizPalette.surface` y `OrtizRadius.sheet`, y sus botones de desplazamiento usan `surfaceHigh`/`line`/`fg`. Test: `test/widgets/responsive_sheet_helper_test.dart`. |
| P-21 | 2026-11-17 | Spec 01, decisión PA-01: el acento de la suite es siempre el coral `OrtizPalette.accent` y `AppColors.primary` es `const`; `AppColors.updateThemeColor` solo guarda `bookColor` (hoy sin lectores: el selector de libro usa el color de cada perfil; queda para el indicador de libro de la spec 02). Cada módulo lee su color de `SuiteApp`, ya no hay `#1F6F5F` fijo en las clases de color. Los `#1F6F5F` literales que quedan en pantallas (p. ej. `quebrado/screens/dashboard_screen.dart:155`) son parte de P-20; los de `app_state.dart` son el color por defecto de un libro (dato). |
