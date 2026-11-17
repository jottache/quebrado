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
| P-10 | media | 5 tests en rojo antes de implantar el sistema agéntico; están congelados en `.claude/known-failures` (la lista solo baja). | `.claude/known-failures` (causa de cada uno en su comentario) | Arreglarlos uno a uno y quitarlos de la lista. |
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
| P-21 | media | `AppColors.updateThemeColor` solo cambia `AppColors`; Diario, Hábitos, sidebar y launcher tienen `#1F6F5F` fijo. | Derivar colores de módulo del primario. |
| P-22 | alta | Accesibilidad: sin `Semantics`/`semanticLabel`; varios colores de texto no cumplen AA; objetivos táctiles < 48. | Spec de accesibilidad. |
| P-23 | media | `ResponsiveBreakpoints.isMedium` e `isDesktop` se solapan entre 840 y 1199; entre 600 y 839 se usa layout móvil. | Definir clases de ventana sin solape. |
| P-24 | media | 63 `showModalBottomSheet` y 95 `showDialog` no pasan por `showResponsiveSheet`; SnackBars sin helper común (algunos muestran `$e`); montos sin separador de miles. | Helpers comunes de feedback y formato de montos. |

## Resueltos
| # | Fecha | Cómo |
| --- | --- | --- |
