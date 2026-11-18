// Ajuste «Cuentas predeterminadas por moneda» (spec 03, diseño U1 de
// docs/design/ortiz-registra.md): una fila por moneda en Ajustes y el
// selector que fija la cuenta que Ortiz usa cuando no le dicen la cuenta.
//
// El estado (cuentas, predeterminada vigente, libro activo) lo da `AppState`;
// este widget solo presenta y llama a `AppState.setDefaultAccount`.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/ortiz_space.dart';
import '../../theme/ortiz_tokens.dart';
import '../../theme/ortiz_type.dart';
import '../../widgets/ortiz/ortiz.dart';
import '../../widgets/responsive_sheet_helper.dart';
import '../models/account.dart';
import '../models/currency_type.dart';
import '../viewmodels/app_state.dart';
import 'currency_pill.dart';
import 'helpers.dart';

/// Orden de las filas: USD, Bs, EUR.
const List<CurrencyType> _currencyOrder = [
  CurrencyType.usd,
  CurrencyType.bsBCV,
  CurrencyType.eur,
];

/// «Dólares», «Bolívares», «Euros» (título de fila y del selector).
String defaultAccountCurrencyTitle(CurrencyType currency) {
  switch (currency) {
    case CurrencyType.usd:
      return 'Dólares';
    case CurrencyType.bsBCV:
      return 'Bolívares';
    case CurrencyType.eur:
      return 'Euros';
  }
}

/// «dólares», «bolívares», «euros» (moneda corta de los textos).
String defaultAccountCurrencyShort(CurrencyType currency) =>
    defaultAccountCurrencyTitle(currency).toLowerCase();

/// Resultado del selector: la cuenta elegida, o `accountId == null` para
/// «Ninguna». Cerrar el selector sin elegir devuelve `null` (no esta clase).
class DefaultAccountChoice {
  const DefaultAccountChoice(this.accountId);

  final String? accountId;
}

/// Filas del grupo «Cuentas predeterminadas por moneda» (sin encabezado ni
/// pie: los pone la pantalla de Ajustes como en los grupos vecinos).
class DefaultAccountRows extends StatefulWidget {
  const DefaultAccountRows({super.key});

  @override
  State<DefaultAccountRows> createState() => _DefaultAccountRowsState();
}

class _DefaultAccountRowsState extends State<DefaultAccountRows> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = OrtizTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final currency in _currencyOrder) _buildRow(app, t, currency),
      ],
    );
  }

  Widget _buildRow(AppState app, OrtizTokens t, CurrencyType currency) {
    final title = defaultAccountCurrencyTitle(currency);
    final leading = CurrencyPill(currency);

    if (!app.isDataLoaded) {
      return OrtizListRow(leading: leading, title: title, subtitle: 'Cargando…');
    }

    final hasAccounts = app.accounts.any((a) => a.currency == currency);
    if (!hasAccounts) {
      return OrtizListRow(
        leading: leading,
        title: title,
        subtitle: 'Aún no tienes cuentas en ${defaultAccountCurrencyShort(currency)}',
      );
    }

    final current = app.defaultAccountFor(currency);
    return MergeSemantics(
      child: Semantics(
        onTapHint: 'Cambiar cuenta predeterminada',
        child: OrtizListRow(
          leading: leading,
          title: title,
          subtitle: current?.name ?? 'Sin predeterminada',
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: OrtizIconSize.md,
            color: t.muted,
          ),
          onTap: () => _choose(currency),
        ),
      ),
    );
  }

  Future<void> _choose(CurrencyType currency) async {
    final app = context.read<AppState>();
    final previousId = app.defaultAccountIdFor(currency);
    final options = app.accounts.where((a) => a.currency == currency).toList();

    final choice = await showResponsiveSheet<DefaultAccountChoice>(
      context: context,
      isScrollControlled: false,
      backgroundColor: null,
      showDragHandle: true,
      builder: (_) => DefaultAccountSheet(
        currency: currency,
        accounts: options,
        selectedId: previousId,
      ),
    );
    // Cerrar sin elegir no cambia nada ni avisa.
    if (choice == null || !mounted) return;

    final short = defaultAccountCurrencyShort(currency);
    // `setDefaultAccount` guarda primero y solo cambia la memoria si se
    // guardó: si falla, la fila sigue mostrando el valor anterior.
    bool saved;
    try {
      saved = await app.setDefaultAccount(currency, choice.accountId);
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    if (!saved) {
      showOrtizNotice(context, 'No pude guardar el cambio. Inténtalo de nuevo.');
      return;
    }

    final chosen = options.where((a) => a.id == choice.accountId).firstOrNull;
    if (chosen == null) {
      showOrtizNotice(context, 'Sin cuenta predeterminada en $short');
    } else {
      showOrtizNotice(
        context,
        '${chosen.name} es tu cuenta predeterminada en $short',
        success: true,
      );
    }
  }
}

/// Selector de la cuenta predeterminada de [currency]: «Ninguna» y las
/// [accounts] de esa moneda. Un toque elige y cierra con un
/// [DefaultAccountChoice].
class DefaultAccountSheet extends StatelessWidget {
  const DefaultAccountSheet({
    super.key,
    required this.currency,
    required this.accounts,
    this.selectedId,
  });

  final CurrencyType currency;
  final List<Account> accounts;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final t = OrtizTokens.of(context);
    final check = Icon(Icons.check_rounded, size: OrtizIconSize.md, color: t.accent);
    void choose(String? id) => Navigator.of(context).pop(DefaultAccountChoice(id));

    return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(OrtizSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Cuenta predeterminada en ${defaultAccountCurrencyTitle(currency)}',
                  style: OrtizType.title.copyWith(color: t.fg),
                ),
              ),
              const SizedBox(height: OrtizSpace.xs),
              Text(
                'Ortiz la usará cuando no digas la cuenta.',
                style: OrtizType.bodySm.copyWith(color: t.muted),
              ),
              const SizedBox(height: OrtizSpace.lg),
              OrtizSection(
                divided: true,
                children: [
                  OrtizListRow(
                    title: 'Ninguna',
                    subtitle: 'Ortiz te preguntará cada vez',
                    selected: selectedId == null,
                    autofocus: selectedId == null,
                    trailing: selectedId == null ? check : null,
                    onTap: () => choose(null),
                  ),
                  for (final account in accounts)
                    OrtizListRow(
                      dotColor: parseHexColor(account.colorHex),
                      title: account.name,
                      selected: account.id == selectedId,
                      autofocus: account.id == selectedId,
                      trailing: account.id == selectedId ? check : null,
                      onTap: () => choose(account.id),
                    ),
                ],
              ),
            ],
          ),
        ),
    );
  }
}
