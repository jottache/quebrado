---
name: ortiz-dark-ui
description: Reglas obligatorias del tema oscuro «Ortiz al centro» para quebrado-app (spec 01). Úsala al crear o cambiar cualquier UI de quebrado-app — pantallas, diálogos, hojas, widgets, colores, textos, espaciados o animaciones en quebrado-app-flutter/lib — y al revisarla. Cubre tokens (OrtizTokens, SuiteApp, OrtizType, OrtizSpace, OrtizRadius, OrtizMotion), «sin tarjetas», contraste, reducir movimiento y una lista de control antes de entregar.
---

# UI oscura de OrtizApp

El detalle (valores, mapa de cada clase de color, componentes tematizados, responsive, transición) está en `docs/design-system.md`. Aquí solo las reglas. Todo vive en `quebrado-app-flutter/lib/theme/`.

## Reglas obligatorias

1. **Solo tokens.** En pantallas nada de `Colors.white`/`Colors.grey…`/`Color(0x…)`, `fontSize:`, `EdgeInsets` con números sueltos ni `BorderRadius.circular(14)`. Usa:
   - color: `OrtizTokens.of(context)` (o `OrtizPalette.x` en `const`), la clase de color del módulo, o `SuiteApp`/`SuiteAppColors`;
   - texto: `OrtizType.x` o `Theme.of(context).textTheme.x`;
   - espacio: `OrtizSpace.xs/sm/md/lg/xl/xxl/xxxl` (4·8·12·16·20·24·32);
   - radio: `OrtizRadius.chip/field/menu/block/dialog/sheet/pillShape`;
   - movimiento: `OrtizMotion`.
   Si falta un token, no lo inventes: pídelo a `ui-ux-designer`. Se tolera `Colors.transparent`.
2. **Sin tarjetas.** Nada de `Card`, `ClaymorphicCard` ni contenedores con sombra nuevos. El contenido va sobre `bg`; los grupos se separan con `OrtizSpace.xxl` y `Divider()` (color `line` del tema); el encabezado de grupo va en `caption`/`titleSm` color `muted`; lo activo, sobre `surfaceHigh`. Solo flotan (sobre `surface`) el menú, las hojas/diálogos y el campo del chat.
3. **Color de app solo vía `SuiteApp`/`SuiteAppColors`** (o la clase del módulo, que ya lo lee de ahí). Nunca un hex de app. El coral `accent` es la única acción principal; el color del libro solo marca el selector de libro.
4. **Texto sobre `accent` o sobre cualquier relleno claro (color de app, estado) = `onAccent`**, nunca blanco.
5. **`faint` nunca para texto que haya que leer** (2,5–2,9:1). Texto secundario = `muted`.
6. **`withValues(alpha: …)`**, no `withOpacity`. En `const`, usa los derivados `SuiteAppColors.xxxTint`/`xxxBorder`.
7. **Animaciones con `OrtizMotion` y respetando reducir movimiento**: duración con `OrtizMotion.of(context, …)`, retrasos con `staggerOf`, curva `OrtizMotion.ease`. `flutter_animate` no lo respeta solo.
8. **Campos de texto a 16 px** (lo pone el tema; no les bajes el tamaño).
9. **Textos en español**, tuteo, sin `$e`. El agente se llama **«Ortiz»**.
10. Responsive y sheets como siempre: `ResponsiveBreakpoints.isDesktop`/`isExpanded` y `showResponsiveSheet`.
11. No migres pantallas existentes «de paso»: lo que veas mal fuera de tu cambio va a `docs/pendientes.md` (spec 05).

## Ejemplos

```dart
// MAL: tarjeta, blanco, literales.
Card(
  elevation: 2,
  child: Padding(
    padding: const EdgeInsets.all(14),
    child: Text('Saldo', style: TextStyle(fontSize: 13, color: Colors.white)),
  ),
);

// BIEN: sobre el fondo, agrupado con espacio y línea.
final t = OrtizTokens.of(context);
Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Text('Saldo', style: OrtizType.caption.copyWith(color: t.muted)),
  const SizedBox(height: OrtizSpace.xs),
  Text(formatUSD(saldo), style: OrtizType.amountLg.copyWith(color: t.fg)),
  const SizedBox(height: OrtizSpace.xxl),
  const Divider(),
]);
```

```dart
// MAL: blanco sobre coral y opacidad deprecada.
Container(color: AppColors.primary, child: Text('Guardar', style: TextStyle(color: Colors.white)));
Icon(Icons.book, color: SuiteApp.diario.color.withOpacity(.5));

// BIEN
FilledButton(onPressed: guardar, child: const Text('Guardar')); // accent + onAccent del tema
Icon(Icons.book, color: SuiteApp.diario.color.withValues(alpha: .5));
const Icon(Icons.book, color: SuiteAppColors.diario); // en const
```

```dart
// MAL: duración fija, ignora reducir movimiento.
child.animate().fadeIn(duration: 300.ms);

// BIEN
final d = OrtizMotion.of(context, OrtizMotion.base);
child.animate(delay: OrtizMotion.staggerOf(context, i))
    .fadeIn(duration: d, curve: OrtizMotion.ease)
    .slideY(begin: .08, end: 0, duration: d, curve: OrtizMotion.ease);
```

## Lista de control antes de entregar

- [ ] `grep` del diff sin `Colors.white`, `Colors.grey`, `Color(0x`, `fontSize:`, `withOpacity`, `EdgeInsets.all(<número fuera de la escala>)` ni `Card(`/`ClaymorphicCard(` nuevos.
- [ ] Ningún texto en `faint`; ningún texto blanco sobre `accent` o color de app.
- [ ] Un solo botón en `accent` por vista.
- [ ] Toda animación usa `OrtizMotion.of`/`staggerOf`; con `disableAnimations: true` no se mueve nada.
- [ ] Probado en compact, medium y expanded (`pumpApp(…, window: WindowClass.x)`, skill `testing`).
- [ ] Estados vacío, carga y error definidos; textos en español; el agente es «Ortiz».
- [ ] Botones solo-icono con `tooltip`; objetivo táctil ≥ 48.
- [ ] `flutter analyze` 0/0 y tests del archivo tocado en verde.
- [ ] Lo visto fuera del cambio, anotado en `docs/pendientes.md`.
