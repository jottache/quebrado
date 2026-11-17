# Plan: proyección y recurrentes en bolívares (Quebrado)

> **Estado (16-nov-2026):** Fases 0, 1 y 2 implementadas, con las decisiones recomendadas:
> - venta el mismo día del gasto;
> - tasa BCV;
> - saldo mostrado como "$ · Bs".
>
> La Fase 3 queda pendiente para después de usarlo. Pruebas en `test/quebrado_bs_projection_test.dart`.

**Objetivo:** que puedas registrar ingresos y gastos recurrentes **en Bs**, y que la proyección entienda
que los gastos en Bs se pagan primero con los Bs que tienes o vas a cobrar, y que solo cuando no alcancen
te sugiera **vender dólares justo a tiempo** (en vez de tener que disfrazar el gasto como si fuera en $).

---

## 1. Diagnóstico: qué pasa hoy

### 1.1 El formulario no permite recurrentes en Bs
- `dialogs/add_recurring_payment_dialog.dart`: con una cuenta en Bs muestra solo las pestañas **USD** y
  **EUR** (el comentario dice "USD, VES, EUR", pero la de Bs no existe). No hay forma de registrar
  "Condominio: Bs 15.000".
- **Error grave al editar** (línea 59): `pay.currency == bsBCV ? usd : pay.currency`. Si un recurrente
  estaba en Bs (por ejemplo, creado antes o importado), al abrirlo y guardarlo pasa a **USD con el mismo
  número**: Bs 3.000 se convierten en $3.000.

### 1.2 La proyección mezcla todo en dólares
`AppState.getTimelineEvents` (`viewmodels/app_state.dart:1825`) simula los saldos por cuenta, pero
después **suma todo convertido a $** (tasa BCV de hoy) y solo muestra ese total:
- Un gasto en Bs resta "su equivalente en $" del total, **sin verificar si hay Bs** en la cuenta.
  Nunca te avisa "ese día no tendrás bolívares", ni que tendrás que vender dólares.
- Un ingreso en Bs suma su equivalente en $, como si esos Bs pudieran pagar cualquier gasto en $.
- No existe el concepto de **cambio de divisa** dentro de la proyección. Por eso hoy registras el gasto en
  $ y vendes a mano, y la proyección queda desfasada.

### 1.3 Los bolsillos solo miran ingresos en $
Dentro de `getTimelineEvents`:
- **Déficit de un bolsillo** (≈ línea 2014): solo busca el último ingreso **en $** para sugerir el
  apartado.
- **Metas con fecha** (≈ línea 2127): reparten el ahorro solo entre los cobros **en $**.
- **Reglas de ahorro** (% o monto fijo, ≈ línea 2289): ignoran los ingresos en Bs.

### 1.4 Errores de unidades (montos en Bs tratados como $)
| Dónde | Problema |
|---|---|
| `timeline_screen.dart` ≈ 380-430 (explicación de la meta de ventas) | `totalIncomeInPeriod += ev.amount` suma Bs como si fueran $. Lo mismo con gastos y reservas. |
| `timeline_event_row.dart` ≈ 1007 (botón "Apartar") | Abona `event.amount` como USD. Si la sugerencia viene de un gasto en Bs, `amount` está en **Bs** y se intentaría apartar Bs 5.000 como $5.000. |
| `app_state.dart` ≈ 2040-2063 (sugerencia por déficit de bolsillo) | Para EUR deja el monto en $ pero marca la moneda como €. |
| `liquidBalanceUSD` (`app_state.dart:741`) vs. proyección | El "dinero disponible" de hoy **excluye** las cuentas en Bs, pero la proyección **las incluye**. Hay un salto entre el saldo de hoy y el primer punto proyectado. |
| `timeline_screen.dart` ≈ 870 (resumen de déficit por cuenta) | No convierte EUR. |

---

## 2. Modelo propuesto

### 2.1 Tres formas de expresar un recurrente en una cuenta en Bs
| Opción en el formulario | Se guarda como | Bs que mueve el día del pago |
|---|---|---|
| ~~Bs fijo~~ **(descartado)**: en Venezuela todo pago en Bs está anclado al dólar o al euro | — | — |
| **USD a tasa BCV**, p. ej. colegio $100 pagado en Bs | `currency = usd` + cuenta Bs | monto × tasa BCV |
| **EUR a tasa BCV** | `currency = eur` + cuenta Bs | monto × tasa € |

En cuentas en $ sigue siendo solo USD. **No hace falta SQL**: la columna `currency` ya acepta `bsBCV`
(`001_quebrado_schema.sql:117`).

### 2.2 Dos "cajas" de dinero en la proyección
La simulación lleva por separado:
- **Caja $**: cuentas en $ − bolsillos (los bolsillos siguen siendo en $; ahorrar en Bs pierde valor).
- **Caja Bs**: cuentas en Bs.

Reglas de cada día (orden: ingresos → cambios → apartados → gastos, como hoy):
1. Los **ingresos** entran a la caja de su cuenta.
2. Los **gastos en Bs** salen de la caja Bs.
3. Si la caja Bs no alcanza, la proyección genera un **cambio sugerido**:
   *"Vender $50 (≈ Bs 5.000) para pagar Condominio"*. Usa justo lo que falta, de la caja $, en la fecha
   del gasto. Si hay varios gastos en Bs el mismo día, se agrupan en un solo cambio.
4. Si la caja $ tampoco alcanza, es un **faltante real** (como hoy) y aparece en rojo.
5. Los **gastos en $** salen de la caja $. Los Bs sobrantes **no** se usan para pagar gastos en $
   (opción futura: sugerir comprar $ con Bs, ver la Fase 4).

**Ejemplo** (tasa 100):

| Día | Evento | Caja Bs | Caja $ |
|---|---|---|---|
| Hoy | Saldos iniciales | 2.000 | 500 |
| 1 | Sueldo en Bs +8.000 | 10.000 | 500 |
| 5 | 💱 Cambio sugerido: vender $50 | 15.000 | 450 |
| 5 | Condominio −15.000 | 0 | 450 |

Hoy la proyección solo restaría $150 del total, sin avisar que te faltan Bs ni cuándo vender.

### 2.3 ¿Cuándo sugerir la venta?
**Recomendado: el mismo día del gasto ("justo a tiempo")**, para no tener Bs devaluándose. Se puede
configurar:
- el mismo día (predeterminado);
- 1 a 3 días antes (si el banco tarda);
- el día del último cobro en $ antes del gasto.

### 2.4 ¿A qué tasa?
- **Predeterminado:** BCV de hoy, que es la que usa toda la app.
- **Ajuste "Tasa para vender $ en la proyección":** BCV / paralelo / tasa manual.
- **Opcional (Fase 4):** usar la tendencia de `BcvPredictor` para estimar la tasa futura. Así, un pago
  "USD a tasa BCV" requiere más Bs con el tiempo, y un "Bs fijo" cuesta menos $.

### 2.5 Qué ves en la proyección
- Cada evento muestra su monto **en su moneda** (Bs 15.000), con el equivalente en $ en gris.
- El saldo del día pasa a **"Disponible: $450 · Bs 0"**. El total consolidado en $ sigue existiendo para
  los gráficos y "Dinero seguro".
- Nueva fila **💱 Cambio sugerido** con su motivo ("para Condominio, Internet") y un botón
  **"Hacer cambio"** que abre el diálogo de cambio de divisa ya rellenado.
- Cuando registras el cambio real, la sugerencia desaparece sola: el motor recalcula con los saldos
  reales y la caja Bs ya no tiene déficit. No hace falta guardar marcas de "cumplido".

---

## 3. Fases

### Fase 0: correcciones (prerrequisito, ~0,5 día)
1. Formulario de recurrentes: agregar la pestaña **Bs** cuando la cuenta es en Bs.
   - Textos: "Bs (monto fijo)" / "USD a tasa BCV" / "EUR a tasa BCV".
   - Quitar la conversión errónea al editar (línea 59).
   - Al cambiar a una cuenta en $, forzar USD (ya lo hace).
2. Sugerencia "Apartar para bolsillo": siempre llevar `amountUSD` en el evento.
   - `TimelineEvent` gana el campo `amountUSD`.
   - El botón "Apartar" abona `amountUSD`, no `amount`.
   - EUR con su moneda real.
3. Resúmenes de la proyección (meta de ventas, pre-cobro, resumen por cuenta): convertir cada evento a $
   con un único helper `eventAmountUSD(event)` en vez de sumar `ev.amount`.
4. Unificar "dinero disponible" entre hoy y la proyección. **Decisión:** el número principal sigue siendo
   **$ líquidos** (sin Bs) y los Bs se muestran aparte, para que coincidan hoy y en la proyección.
5. Pruebas:
   - editar un recurrente en Bs no lo convierte;
   - apartar desde una sugerencia de gasto en Bs abona el monto en $;
   - los resúmenes no mezclan monedas.

### Fase 1: motor por moneda (~1,5 días)
En `getTimelineEvents`:
1. Separar la simulación en **caja $** y **caja Bs**. Se mantienen las cuentas individuales para el
   resumen por cuenta.
2. Nuevo tipo de evento simulado `_SimExchange`. Se genera en un pase previo, igual que hoy se generan los
   apartados por déficit de bolsillo:
   - recorrer los eventos en orden, llevando la caja Bs;
   - ante un gasto en Bs sin fondos, crear o sumar un cambio en la fecha elegida (2.3), por el faltante.
     Convertir a $ con la tasa elegida (2.4), redondeando hacia arriba al centavo de $;
   - si la caja $ de ese día no alcanza, el cambio se limita a lo disponible y el resto queda como
     faltante.
3. `TimelineEvent` gana:
   - `projectedLiquidUSD`: caja $ − bolsillos;
   - `projectedBs`: caja Bs;
   - `isExchangeSuggestion` y `exchangeAmountUSD` / `exchangeAmountBs`.

   `projectedLiquidBalanceUSD` se conserva con el mismo significado (consolidado en $) para no romper
   el gráfico ni "Dinero seguro".
4. Los ingresos en Bs cubren gastos en Bs antes de sugerir vender $.
5. Ajustes nuevos, en la tabla `settings` (sin SQL):
   - `projection_exchange_timing`: `same_day` | `days_before:N` | `last_usd_payday`;
   - `projection_exchange_rate_source`: `bcv` | `parallel` | `manual:<tasa>`.
6. Pruebas unitarias del motor:
   - ejemplo de 2.2;
   - un ingreso en Bs que cubre el gasto (sin cambio);
   - dos gastos en Bs el mismo día (un solo cambio);
   - sin $ suficientes (cambio parcial + faltante);
   - pago "USD a tasa BCV" desde una cuenta en Bs;
   - registrar el cambio real hace desaparecer la sugerencia.

### Fase 2: pantallas (~1,5 días)
1. **Fila de proyección** (`timeline_event_row.dart`):
   - monto en su moneda + equivalente;
   - saldo "Disponible: $X · Bs Y";
   - estilo propio 💱 para los cambios sugeridos.
2. **Detalle del cambio sugerido:**
   - motivo (qué gastos cubre);
   - tasa usada;
   - botón **"Hacer cambio"** → `add_exchange_dialog` con cuentas $/Bs, monto y tasa prellenados.
3. **Confirmar un pago en Bs sin saldo suficiente** (`pending_confirmations_dialog` / confirmación del
   recurrente):
   - mostrar "Te faltan Bs 5.000 en Banesco. ¿Vender $50 a tasa 100 y pagar?";
   - la acción **"Vender y pagar"** ejecuta `exchangeCurrency` + `confirmRecurringPayment` en un paso.

   Es exactamente lo que haces hoy a mano.
4. **Filtros de la proyección:** agregar "Cambios" junto a ingresos, gastos y sugerencias.
5. **Resumen de proyección (bottom sheet):** sección "Bolívares", que dice:
   - cuántos Bs necesitas en los próximos 30 días;
   - cuántos cubren tus ingresos en Bs;
   - cuántos $ tendrás que vender y en qué fechas.
6. **Gráfico del dashboard:** sin cambios de cálculo. Opcional: una segunda línea con la caja Bs en $.

### Fase 3: bolsillos con gastos en Bs (~1 día)
1. **Gasto en Bs ligado a un bolsillo** (p. ej. bolsillo "Colegio" en $ que paga Bs):
   - el bolsillo se sigue provisionando en $, a partir del monto convertido;
   - el día del pago, el cambio sugerido sale **del bolsillo**: "Retirar $100 de Colegio y vender".
2. **Reglas de ahorro con ingresos en Bs:** nueva opción por bolsillo
   "Aplicar también a ingresos en Bs" (predeterminado: no). Si se activa, la sugerencia es
   "Comprar $X con Bs y apartar".
   - Requiere un campo nuevo en `saving_pockets` → **SQL 017** (lo entregaría en esa fase):
     `ALTER TABLE saving_pockets ADD COLUMN IF NOT EXISTS include_ves_income BOOLEAN DEFAULT false;`
3. **Metas con fecha:** opción de contar también los cobros en Bs para repartir el ahorro (misma
   bandera).

### Fase 4: opcional, después de usarlo
- Tasa futura estimada con `BcvPredictor` (interruptor "Proyectar devaluación").
- Sugerir **comprar $ con Bs sobrantes** antes de un gasto en $ ("tienes Bs 20.000 ociosos").
- Aviso de "Bs ociosos": Bs que pasan más de N días sin usarse y pierden valor.

---

## 4. Decisiones que necesito que confirmes
1. **¿Cuándo sugerir la venta de $?** Recomiendo **el mismo día del gasto**, configurable.
2. **¿Qué tasa usar para vender en la proyección?** Recomiendo **BCV** por defecto, con opción de
   paralelo o tasa manual.
3. **Saldo principal de la proyección:** ¿mostrar **"$ disponible · Bs disponible"** por separado
   (recomendado) o un solo número consolidado en $?
4. **¿Hacer la Fase 3 (bolsillos + ingresos en Bs) ahora o después de usar las Fases 0-2?**
   Recomiendo después: es la única que requiere SQL.

## 5. Riesgos
- `getTimelineEvents` es grande (≈1.000 líneas) y lo usan dashboard, bolsillos, simulador de compras
  y "Dinero seguro". Mitigación:
  - mantener los campos actuales con el mismo significado y agregar los nuevos;
  - cubrir el motor con pruebas antes de tocar las pantallas.
- Recurrentes existentes guardados como USD que en realidad pagas en Bs: no se tocan solos. Después de
  la Fase 0 puedes editarlos y elegir "Bs fijo" o "USD a tasa BCV".
- Tasa: la proyección usa la tasa de hoy para todo el año (como ya pasa). Los montos en Bs a meses de
  distancia son aproximados hasta la Fase 4.

## 6. Estimación
| Fase | Esfuerzo | SQL |
|---|---|---|
| 0. Correcciones | ~0,5 día | No |
| 1. Motor por moneda | ~1,5 días | No |
| 2. Pantallas + "Vender y pagar" | ~1,5 días | No |
| 3. Bolsillos e ingresos en Bs | ~1 día | Sí (017) |
| 4. Opcionales | a definir | No |
