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
  String? _copiedRateName;

  double get _amount => double.tryParse(_amountText) ?? 0.0;

  double _getBcvConverted(AppState appState) {
    if (_selectedCurrency == CurrencyType.usd) {
      return _amount * appState.bcvRate;
    } else {
      return appState.bcvRate > 0 ? _amount / appState.bcvRate : 0.0;
    }
  }

  double _getParallelConverted(AppState appState) {
    if (_selectedCurrency == CurrencyType.usd) {
      return _amount * appState.parallelRate;
    } else {
      return appState.parallelRate > 0 ? _amount / appState.parallelRate : 0.0;
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
    setState(() {
      _copiedRateName = rateName;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _copiedRateName == rateName) {
        setState(() {
          _copiedRateName = null;
        });
      }
    });
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
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
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
                  ? const Icon(
                      Icons.backspace_rounded,
                      size: 18,
                      color: AppColors.expense,
                    )
                  : Text(
                      label,
                      style: const TextStyle(
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
    return ClaymorphicCard(
      cornerRadius: 16,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _copyToClipboard(value, title),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
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
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cardSubtitleText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.copy_rounded,
                    size: 10,
                    color: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "$symbol${value.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.cardText,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "Tasa: ${rate.toStringAsFixed(2)}",
                  style: const TextStyle(
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
        borderRadius: const BorderRadius.only(
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Calculadora de Divisas",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

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
            const SizedBox(height: 12),

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
                const SizedBox(width: 8),
                Expanded(
                  child: _buildConversionCard(
                    title: "Euro",
                    rate: appState.euroRate,
                    value: _getEuroConverted(appState),
                    symbol: _selectedCurrency == CurrencyType.usd ? "Bs." : "\$",
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildConversionCard(
                    title: "Paralelo",
                    rate: appState.parallelRate,
                    value: _getParallelConverted(appState),
                    symbol: _selectedCurrency == CurrencyType.usd ? "Bs." : "\$",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Copied Toast Status
            if (_copiedRateName != null) ...[
              AnimatedOpacity(
                opacity: _copiedRateName != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.income.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "¡Copiado valor de $_copiedRateName al portapapeles!",
                    style: const TextStyle(
                      color: AppColors.income,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 2. Amount Input Card (Middle)
            ClaymorphicCard(
              cornerRadius: 24,
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
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
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(4),
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
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
            const SizedBox(height: 16),

            // Transferir a banco Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => TransferBankBottomSheet(
                    initialAmount: _amount,
                    selectedCurrency: _selectedCurrency,
                    appState: appState,
                  ),
                );
              },
              icon: const Icon(Icons.account_balance_rounded, size: 18),
              label: const Text(
                "Transferir a banco",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Custom Keyboard (Bottom)
            _buildKeyboard(),
          ],
        ),
      ),
    );
  }
}
