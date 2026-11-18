import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../models/account.dart';
import '../models/currency_type.dart';
import '../theme/colors.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';
import '../widgets/helpers.dart';
import '../../widgets/responsive_breakpoints.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
class AddAccountBottomSheet extends StatefulWidget {
  final Account? editingAccount;

  const AddAccountBottomSheet({super.key, this.editingAccount});

  @override
  State<AddAccountBottomSheet> createState() => _AddAccountBottomSheetState();
}

class _AddAccountBottomSheetState extends State<AddAccountBottomSheet> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  CurrencyType _selectedCurrency = CurrencyType.usd;
  late String _selectedColorHex;
  late String _selectedIcon;

  final List<String> _colors = AppColors.creationColors;
  final List<String> _icons = [
    "creditcard", "wallet", "bank", "briefcase", "computer", "gift",
    "trendingup", "restaurant", "localcafe", "cart", "bag", "car",
    "home", "bolt", "gamecontroller", "heart", "airplane", "tv",
    "book", "musicnote", "medical", "pills", "tag", "shield",
    "iphone", "star", "wifi", "person", "clock", "gear",
    "calculator", "ellipsis"
  ];

  @override
  void initState() {
    super.initState();
    final acc = widget.editingAccount;
    if (acc != null) {
      _nameController.text = acc.name;
      _balanceController.text = acc.balance.toStringAsFixed(2);
      _selectedCurrency = acc.currency;
      _selectedColorHex = acc.colorHex;
      _selectedIcon = acc.icon;
    } else {
      _selectedIcon = _icons[0];
      _selectedColorHex = _colors[1]; // Default green
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _saveAccount(AppState appState) {
    final name = _nameController.text.trim();
    final balance = double.tryParse(_balanceController.text.trim()) ?? 0.0;
    if (name.isEmpty) return;

    if (widget.editingAccount != null) {
      final updated = Account(
        id: widget.editingAccount!.id,
        name: name,
        currency: _selectedCurrency,
        balance: balance,
        colorHex: _selectedColorHex,
        icon: _selectedIcon,
      );
      appState.updateAccount(updated);
    } else {
      appState.addAccount(
        name: name,
        currency: _selectedCurrency,
        initialBalance: balance,
        colorHex: _selectedColorHex,
        icon: _selectedIcon,
      );
    }
    Navigator.pop(context);
  }

  void _deleteAccount(AppState appState) {
    if (widget.editingAccount != null) {
      appState.deleteAccount(widget.editingAccount!.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final themeColor = parseHexColor(_selectedColorHex);
    final isDefaultAccount = widget.editingAccount != null &&
        (widget.editingAccount!.id == 'default_usd' || widget.editingAccount!.id == 'default_ves');
    final canDelete = widget.editingAccount != null && appState.accounts.length > 1 && !isDefaultAccount;
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: isDesktop
            ? const BorderRadius.only(
                topLeft: Radius.circular(OrtizRadius.sheet),
                bottomLeft: Radius.circular(OrtizRadius.sheet),
              )
            : const BorderRadius.only(
                topLeft: Radius.circular(OrtizRadius.pill),
                topRight: Radius.circular(OrtizRadius.pill),
              ),
      ),
      padding: EdgeInsets.only(
        left: OrtizSpace.xl,
        right: OrtizSpace.xl,
        top: isDesktop ? OrtizSpace.xxl : OrtizSpace.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + OrtizSpace.xl,
      ),
      child: FractionallySizedBox(
        heightFactor: isDesktop ? 1.0 : 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isDesktop) ...[
              // Top drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: OrtizPalette.line,
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  ),
                ),
              ),
              const SizedBox(height: OrtizSpace.lg),
            ],

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.editingAccount == null ? "Nueva Cuenta" : "Editar Cuenta",
                  style: const TextStyle(
                    fontSize: OrtizFontSize.title,
                    fontWeight: FontWeight.w900,
                    color: OrtizPalette.fg,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: OrtizSpace.lg),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Information Section
                    OrtizSection(
                      title: "DETALLES DE LA CUENTA",
                      children: [
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: "Nombre (ej. Banesco Bs, Efectivo \$)",
                              hintStyle: const TextStyle(color: OrtizPalette.muted, fontSize: OrtizFontSize.bodySm),
                              contentPadding: const EdgeInsets.all(OrtizSpace.md),
                              filled: true,
                              fillColor: OrtizPalette.surfaceHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: TextStyle(fontSize: OrtizFontSize.body, color: AppColors.cardText),
                            onChanged: (_) => setState(() {}),
                          ),
                          SizedBox(height: OrtizSpace.md),
                          TextField(
                            controller: _balanceController,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: "Monto / Saldo Actual",
                              hintStyle: const TextStyle(color: OrtizPalette.muted, fontSize: OrtizFontSize.bodySm),
                              contentPadding: const EdgeInsets.all(OrtizSpace.md),
                              filled: true,
                              fillColor: OrtizPalette.surfaceHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: TextStyle(fontSize: OrtizFontSize.body, color: AppColors.cardText),
                            onChanged: (_) => setState(() {}),
                          ),
                          if (widget.editingAccount != null) ...[
                            SizedBox(height: OrtizSpace.xs),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xs),
                              child: Text(
                                "Nota: Si editas este campo, ajustarás el saldo de la cuenta de forma directa. No se crearán transacciones ficticias ni se afectarán tus gráficas de ingresos y gastos.",
                                style: const TextStyle(
                                  fontSize: OrtizFontSize.caption,
                                  color: OrtizPalette.muted,
                                  height: 1.3,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: OrtizSpace.lg),
                           Container(
                            padding: EdgeInsets.all(OrtizSpace.xs),
                            decoration: BoxDecoration(
                              color: AppColors.nestedTabTrackBg,
                              borderRadius: BorderRadius.circular(OrtizRadius.field),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: isDefaultAccount ? null : () => setState(() => _selectedCurrency = CurrencyType.usd),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                                      decoration: BoxDecoration(
                                        color: _selectedCurrency == CurrencyType.usd
                                            ? AppColors.nestedTabActiveBg.withValues(alpha: isDefaultAccount ? 0.6 : 1.0)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "Dólares (\$)",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: OrtizFontSize.bodySm,
                                          color: _selectedCurrency == CurrencyType.usd
                                              ? AppColors.nestedTabActiveText.withValues(alpha: isDefaultAccount ? 0.8 : 1.0)
                                              : AppColors.nestedTabInactiveText.withValues(alpha: isDefaultAccount ? 0.3 : 1.0),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: isDefaultAccount ? null : () => setState(() => _selectedCurrency = CurrencyType.bsBCV),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                                      decoration: BoxDecoration(
                                        color: _selectedCurrency == CurrencyType.bsBCV
                                            ? AppColors.nestedTabActiveBg.withValues(alpha: isDefaultAccount ? 0.6 : 1.0)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "Bolívares (Bs.)",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: OrtizFontSize.bodySm,
                                          color: _selectedCurrency == CurrencyType.bsBCV
                                              ? AppColors.nestedTabActiveText.withValues(alpha: isDefaultAccount ? 0.8 : 1.0)
                                              : AppColors.nestedTabInactiveText.withValues(alpha: isDefaultAccount ? 0.3 : 1.0),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isDefaultAccount)
                            Padding(
                              padding: EdgeInsets.only(top: OrtizSpace.sm, left: OrtizSpace.xs),
                              child: Text(
                                "La moneda de la cuenta principal no se puede modificar.",
                                style: const TextStyle(
                                  fontSize: OrtizFontSize.caption,
                                  color: OrtizPalette.muted,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                      ],
                    ),

                    // Icon Section
                    OrtizSection(
                      title: "ICONO",
                      children: [
                          GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.2,
                            ),
                            itemCount: _icons.length,
                            itemBuilder: (context, index) {
                              final icon = _icons[index];
                              final isSelected = _selectedIcon == icon;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedIcon = icon),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? themeColor : themeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                                  ),
                                  child: Icon(
                                    getIconData(icon),
                                    color: isSelected ? OrtizPalette.onAccent : themeColor,
                                    size: OrtizIconSize.md,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),

                    // Color Section
                    OrtizSection(
                      title: "COLOR",
                      children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: _colors.map((colorHex) {
                              final isSelected = _selectedColorHex == colorHex;
                              final color = parseHexColor(colorHex);
                              return GestureDetector(
                                onTap: () => setState(() => _selectedColorHex = colorHex),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? OrtizPalette.fg : Colors.transparent,
                                      width: isSelected ? 2.5 : 0,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),

                    // Destructive Delete Button
                    if (canDelete) ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.expense.withValues(alpha: 0.08),
                          foregroundColor: AppColors.expense,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                        ),
                        onPressed: () => _deleteAccount(appState),
                        child: Text(
                          "Eliminar Cuenta",
                          style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    SizedBox(height: OrtizSpace.xxxl),
                  ],
                ),
              ),
            ),
            SizedBox(height: OrtizSpace.md),

            // Save / Cancel Buttons Row
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancelar",
                      style: const TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold, color: OrtizPalette.muted),
                    ),
                  ),
                ),
                SizedBox(width: OrtizSpace.md),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: OrtizPalette.onAccent,
                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                    ),
                    onPressed: _nameController.text.trim().isEmpty ? null : () => _saveAccount(appState),
                    child: Text(
                      "Guardar",
                      style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
