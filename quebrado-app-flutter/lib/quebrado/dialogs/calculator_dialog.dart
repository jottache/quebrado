import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../models/currency_type.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';
import 'transfer_bank_dialog.dart';
import '../../widgets/responsive_breakpoints.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
class CalculatorBottomSheet extends StatefulWidget {
  const CalculatorBottomSheet({super.key});

  @override
  State<CalculatorBottomSheet> createState() => _CalculatorBottomSheetState();
}

class _CalculatorBottomSheetState extends State<CalculatorBottomSheet> {
  String _amountText = "";
  CurrencyType _selectedCurrency = CurrencyType.usd;
  String _selectedRate = "BCV";

  double get _amount => double.tryParse(_amountText) ?? 0.0;

  double _getBcvConverted(AppState appState) {
    if (_selectedCurrency == CurrencyType.usd) {
      return _amount * appState.bcvRate;
    } else {
      return appState.bcvRate > 0 ? _amount / appState.bcvRate : 0.0;
    }
  }



  double _getEuroConverted(AppState appState) {
    if (_selectedCurrency == CurrencyType.usd) {
      return _amount * appState.euroRate;
    } else {
      return appState.euroRate > 0 ? _amount / appState.euroRate : 0.0;
    }
  }

  void _copyToClipboard(double value, String rateName) {
    final formattedValue = value.toStringAsFixed(2);
    Clipboard.setData(ClipboardData(text: formattedValue));
    _showFloatingToast(context, "¡Copiado valor de $rateName al portapapeles!");
  }

  void _showFloatingToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
  }

  void _onKeyPress(String char) {
    setState(() {
      if (char == ".") {
        if (_amountText.contains(".")) {
          return;
        }
        if (_amountText.isEmpty) {
          _amountText = "0.";
          return;
        }
      }
      if (_amountText.contains(".")) {
        final parts = _amountText.split(".");
        if (parts.length > 1 && parts[1].length >= 2) {
          return;
        }
      }
      if (_amountText == "0" && char != ".") {
        _amountText = char;
      } else {
        _amountText += char;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_amountText.isNotEmpty) {
        _amountText = _amountText.substring(0, _amountText.length - 1);
      }
    });
  }

  void _onClear() {
    setState(() {
      _amountText = "";
    });
  }

  Widget _buildKey(String label, {bool isBackspace = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xs),
        child: Material(
          color: isBackspace
              ? OrtizPalette.badTint
              : OrtizPalette.surfaceHigh,
          borderRadius: BorderRadius.circular(OrtizRadius.block),
          child: InkWell(
            borderRadius: BorderRadius.circular(OrtizRadius.block),
            onTap: () {
              if (isBackspace) {
                _onBackspace();
              } else {
                _onKeyPress(label);
              }
            },
            onLongPress: isBackspace ? _onClear : null,
            child: Container(
              height: OrtizSize.minTouch,
              alignment: Alignment.center,
              child: isBackspace
                  ? const Icon(
                      Icons.backspace_rounded,
                      size: OrtizIconSize.md,
                      color: AppColors.expense,
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: OrtizFontSize.title,
                        fontWeight: FontWeight.w900,
                        color: AppColors.cardText,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboard() {
    return Column(
      children: [
        Row(
          children: [
            _buildKey("1"),
            _buildKey("2"),
            _buildKey("3"),
          ],
        ),
        Row(
          children: [
            _buildKey("4"),
            _buildKey("5"),
            _buildKey("6"),
          ],
        ),
        Row(
          children: [
            _buildKey("7"),
            _buildKey("8"),
            _buildKey("9"),
          ],
        ),
        Row(
          children: [
            _buildKey("."),
            _buildKey("0"),
            _buildKey("⌫", isBackspace: true),
          ],
        ),
      ],
    );
  }

  Widget _buildConversionCard({
    required String title,
    required double rate,
    required double value,
    required String symbol,
  }) {
    final isSelected = _selectedRate == title;

    // Sin tarjeta: la opción activa va sobre `surfaceHigh` con borde `accent`.
    return Material(
      color: isSelected ? OrtizPalette.surfaceHigh : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OrtizRadius.block),
        side: BorderSide(
          color: isSelected ? AppColors.primary : OrtizPalette.line,
          width: isSelected ? OrtizStroke.focus : OrtizStroke.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedRate = title;
          });
          _copyToClipboard(value, title);
        },
        borderRadius: BorderRadius.circular(OrtizRadius.block),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: OrtizSpace.md, horizontal: OrtizSpace.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: OrtizFontSize.caption,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardSubtitleText,
                    ),
                  ),
                  SizedBox(width: OrtizSpace.xs),
                  const Icon(
                    Icons.copy_rounded,
                    size: OrtizIconSize.xs,
                    color: AppColors.primary,
                  ),
                ],
              ),
              SizedBox(height: OrtizSpace.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "$symbol${value.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: OrtizFontSize.titleSm,
                    fontWeight: FontWeight.w900,
                    color: AppColors.cardText,
                  ),
                ),
              ),
              SizedBox(height: OrtizSpace.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "Tasa: ${rate.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: OrtizFontSize.micro,
                    color: AppColors.cardSubtitleText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
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
        bottom: MediaQuery.of(context).padding.bottom + OrtizSpace.lg,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Calculadora de Divisas",
                  style: TextStyle(
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

            // 1. Conversion List (Top)
            OrtizSection(
              title: "CONVERSIONES EN TIEMPO REAL",
              children: [
            Row(
              children: [
                Expanded(
                  child: _buildConversionCard(
                    title: "BCV",
                    rate: appState.bcvRate,
                    value: _getBcvConverted(appState),
                    symbol: _selectedCurrency == CurrencyType.usd ? "Bs." : "\$",
                  ),
                ),
                SizedBox(width: OrtizSpace.sm),
                Expanded(
                  child: _buildConversionCard(
                    title: "Euro",
                    rate: appState.euroRate,
                    value: _getEuroConverted(appState),
                    symbol: _selectedCurrency == CurrencyType.usd ? "Bs." : "\$",
                  ),
                ),
              ],
            ),
              ],
            ),

            // 2. Amount Input (Middle), sin tarjeta
            OrtizSection(
              title: "INGRESA EL MONTO",
              children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                    child: Text(
                      _amountText.isEmpty ? "0.00" : _amountText,
                      style: TextStyle(
                        fontSize: OrtizFontSize.displayLg,
                        fontWeight: FontWeight.w900,
                        color: _amountText.isEmpty
                            ? AppColors.cardSubtitleText.withValues(alpha: 0.5)
                            : AppColors.cardText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: OrtizSpace.md),
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
                            onTap: () => setState(() => _selectedCurrency = CurrencyType.usd),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                              decoration: BoxDecoration(
                                color: _selectedCurrency == CurrencyType.usd
                                    ? AppColors.nestedTabActiveBg
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "USD",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: OrtizFontSize.bodySm,
                                  color: _selectedCurrency == CurrencyType.usd
                                      ? AppColors.nestedTabActiveText
                                      : AppColors.nestedTabInactiveText,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedCurrency = CurrencyType.bsBCV),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                              decoration: BoxDecoration(
                                color: _selectedCurrency == CurrencyType.bsBCV
                                    ? AppColors.nestedTabActiveBg
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "Bs. BCV",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: OrtizFontSize.bodySm,
                                  color: _selectedCurrency == CurrencyType.bsBCV
                                      ? AppColors.nestedTabActiveText
                                      : AppColors.nestedTabInactiveText,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Transferir a banco Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: OrtizPalette.onAccent,
                padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(OrtizRadius.block),
                ),
                elevation: 0,
              ),
              onPressed: () {
                double transferAmount = 0.0;
                if (_selectedCurrency == CurrencyType.usd) {
                  if (_selectedRate == "BCV") {
                    transferAmount = _getBcvConverted(appState);
                  } else {
                    transferAmount = _getEuroConverted(appState);
                  }
                } else {
                  transferAmount = _amount;
                }

                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => TransferBankBottomSheet(
                    initialAmount: transferAmount,
                    selectedCurrency: CurrencyType.bsBCV,
                    appState: appState,
                    openedFromCalculator: true,
                  ),
                );
              },
              icon: const Icon(Icons.account_balance_rounded, size: OrtizIconSize.md),
              label: Text(
                "Transferir a banco",
                style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: OrtizSpace.lg),

            // 3. Custom Keyboard (Bottom)
            _buildKeyboard(),
          ],
        ),
      ),
    );
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slide = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.45,
      left: 32,
      right: 32,
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.translate(
                offset: Offset(0.0, _slide.value),
                child: child,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: OrtizSpace.md, horizontal: OrtizSpace.xxl),
            decoration: BoxDecoration(
              color: OrtizPalette.surfaceHigh,
              borderRadius: BorderRadius.circular(OrtizRadius.sheet),
              border: Border.all(color: OrtizPalette.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.income,
                  size: OrtizIconSize.md,
                ),
                const SizedBox(width: OrtizSpace.sm),
                Expanded(
                  child: Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: OrtizPalette.fg,
                      fontSize: OrtizFontSize.bodySm,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
