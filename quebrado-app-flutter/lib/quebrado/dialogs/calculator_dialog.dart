import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../models/currency_type.dart';
import '../widgets/claymorphic_card.dart';
import 'transfer_bank_dialog.dart';

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
        padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: Material(
          color: isBackspace
              ? AppColors.expense.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (isBackspace) {
                _onBackspace();
              } else {
                _onKeyPress(label);
              }
            },
            onLongPress: isBackspace ? _onClear : null,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isBackspace
                      ? AppColors.expense.withOpacity(0.2)
                      : AppColors.cardBorderColor,
                  width: 1.0,
                ),
              ),
              child: isBackspace
                  ? Icon(
                      Icons.backspace_rounded,
                      size: 18,
                      color: AppColors.expense,
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontSize: 18,
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

    return ClaymorphicCard(
      cornerRadius: 16,
      padding: EdgeInsets.zero,
      borderColor: isSelected ? AppColors.primary : null,
      borderWidth: isSelected ? 2.5 : null,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedRate = title;
          });
          _copyToClipboard(value, title);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
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
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardSubtitleText,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.copy_rounded,
                    size: 10,
                    color: AppColors.primary,
                  ),
                ],
              ),
              SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "$symbol${value.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.cardText,
                  ),
                ),
              ),
              SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "Tasa: ${rate.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 9,
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 20.0,
        bottom: MediaQuery.of(context).padding.bottom + 16.0,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top drag handle
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Calculadora de Divisas",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 16),

            // 1. Conversion List (Top)
            Text(
              "CONVERSIONES EN TIEMPO REAL",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 12),

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
                SizedBox(width: 8),
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
            SizedBox(height: 16),



            // 2. Amount Input Card (Middle)
            ClaymorphicCard(
              cornerRadius: 24,
              padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
              child: Column(
                children: [
                  Text(
                    "INGRESA EL MONTO",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.cardSubtitleText,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      _amountText.isEmpty ? "0.00" : _amountText,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: _amountText.isEmpty
                            ? AppColors.cardSubtitleText.withOpacity(0.5)
                            : AppColors.cardText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.nestedTabTrackBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedCurrency = CurrencyType.usd),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedCurrency == CurrencyType.usd
                                    ? AppColors.nestedTabActiveBg
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "USD",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
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
                              padding: EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedCurrency == CurrencyType.bsBCV
                                    ? AppColors.nestedTabActiveBg
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "Bs. BCV",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
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
            ),
            SizedBox(height: 16),

            // Transferir a banco Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
              icon: Icon(Icons.account_balance_rounded, size: 18),
              label: Text(
                "Transferir a banco",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 16),

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
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.income,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
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
