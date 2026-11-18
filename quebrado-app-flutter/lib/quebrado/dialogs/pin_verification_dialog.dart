import 'package:flutter/material.dart';
import '../theme/colors.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

class PinVerificationDialog extends StatefulWidget {
  final String correctPin;
  final String title;
  final String subtitle;

  const PinVerificationDialog({
    super.key,
    required this.correctPin,
    this.title = "Confirmar Acción",
    this.subtitle = "Ingresa tu PIN de seguridad de 4 dígitos para continuar",
  });

  @override
  State<PinVerificationDialog> createState() => _PinVerificationDialogState();
}

class _PinVerificationDialogState extends State<PinVerificationDialog> {
  String _inputPin = "";
  String? _errorMessage;

  void _onNumberTap(int val) {
    if (_inputPin.length < 4) {
      setState(() {
        _inputPin += val.toString();
        _errorMessage = null;
      });
      
      if (_inputPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspaceTap() {
    if (_inputPin.isNotEmpty) {
      setState(() {
        _inputPin = _inputPin.substring(0, _inputPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _verifyPin() {
    if (_inputPin == widget.correctPin) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _inputPin = "";
        _errorMessage = "PIN incorrecto. Inténtalo de nuevo.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OrtizRadius.sheet),
      ),
      backgroundColor: OrtizPalette.surface,
      child: Padding(
        padding: EdgeInsets.all(OrtizSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: OrtizFontSize.title,
                fontWeight: FontWeight.w900,
                color: AppColors.cardText,
              ),
            ),
            SizedBox(height: OrtizSpace.sm),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: OrtizFontSize.bodySm,
                color: AppColors.cardSubtitleText,
                height: 1.3,
              ),
            ),
            SizedBox(height: OrtizSpace.xxl),
            // Pin indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _inputPin.length;
                return AnimatedContainer(
                  duration: Duration(milliseconds: 150),
                  margin: EdgeInsets.symmetric(horizontal: OrtizSpace.sm),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isFilled ? AppColors.primary : OrtizPalette.surfaceHigh,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isFilled ? AppColors.primary : OrtizPalette.line,
                      width: 1.5,
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: OrtizSpace.lg),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.expense,
                  fontSize: OrtizFontSize.bodySm,
                  fontWeight: FontWeight.bold,
                ),
              ),
            SizedBox(height: OrtizSpace.xxl),
            // Number keypad grid
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [1, 2, 3].map((val) => _buildKeypadButton(val)).toList(),
                ),
                SizedBox(height: OrtizSpace.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [4, 5, 6].map((val) => _buildKeypadButton(val)).toList(),
                ),
                SizedBox(height: OrtizSpace.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [7, 8, 9].map((val) => _buildKeypadButton(val)).toList(),
                ),
                SizedBox(height: OrtizSpace.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.cardSubtitleText,
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(OrtizSpace.lg),
                        ),
                        child: Text(
                          "Cancelar",
                          style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    _buildKeypadButton(0),
                    Expanded(
                      child: IconButton(
                        onPressed: _onBackspaceTap,
                        icon: Icon(Icons.backspace_outlined),
                        color: AppColors.cardText,
                        iconSize: 20,
                        padding: EdgeInsets.all(OrtizSpace.lg),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadButton(int val) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xs),
        child: InkWell(
          onTap: () => _onNumberTap(val),
          borderRadius: BorderRadius.circular(OrtizRadius.pill),
          child: Container(
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: OrtizPalette.surfaceHigh,
              shape: BoxShape.circle,
              border: Border.all(color: OrtizPalette.line, width: OrtizStroke.hairline),
            ),
            child: Text(
              val.toString(),
              style: TextStyle(
                fontSize: OrtizFontSize.title,
                fontWeight: FontWeight.w900,
                color: AppColors.cardText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
