import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

enum PinSetupMode { create, update }

class PinSetupBottomSheet extends StatefulWidget {
  final PinSetupMode mode;
  final String? currentPin; // only needed if updating

  const PinSetupBottomSheet({
    super.key,
    required this.mode,
    this.currentPin,
  });

  @override
  State<PinSetupBottomSheet> createState() => _PinSetupBottomSheetState();
}

class _PinSetupBottomSheetState extends State<PinSetupBottomSheet> {
  // Steps:
  // For create: 1 = Enter new PIN, 2 = Confirm new PIN
  // For update: 1 = Enter current PIN, 2 = Enter new PIN, 3 = Confirm new PIN
  int _currentStep = 1;
  
  String _currentPinInput = "";
  String _newPinInput = "";
  String _confirmPinInput = "";
  
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Default step initialization
    _currentStep = 1;
  }

  String get _title {
    if (widget.mode == PinSetupMode.create) {
      return _currentStep == 1 
          ? "Crea tu PIN de Seguridad" 
          : "Confirma tu PIN";
    } else {
      if (_currentStep == 1) return "Introduce PIN Actual";
      if (_currentStep == 2) return "Nuevo PIN de Seguridad";
      return "Confirma el Nuevo PIN";
    }
  }

  String get _subtitle {
    if (widget.mode == PinSetupMode.create) {
      return _currentStep == 1
          ? "Define un código de 4 dígitos para proteger tus restauraciones"
          : "Vuelve a escribir el código para confirmar";
    } else {
      if (_currentStep == 1) return "Ingresa tu PIN actual para poder modificarlo";
      if (_currentStep == 2) return "Define tu nuevo código de 4 dígitos";
      return "Confirma tu nuevo código de 4 dígitos";
    }
  }

  String get _activeInput {
    if (widget.mode == PinSetupMode.create) {
      return _currentStep == 1 ? _newPinInput : _confirmPinInput;
    } else {
      if (_currentStep == 1) return _currentPinInput;
      if (_currentStep == 2) return _newPinInput;
      return _confirmPinInput;
    }
  }

  void _onNumberTap(int val) {
    setState(() {
      _errorMessage = null;
    });

    if (widget.mode == PinSetupMode.create) {
      if (_currentStep == 1) {
        if (_newPinInput.length < 4) {
          setState(() => _newPinInput += val.toString());
          if (_newPinInput.length == 4) {
            Future.delayed(Duration(milliseconds: 200), () {
              setState(() => _currentStep = 2);
            });
          }
        }
      } else {
        if (_confirmPinInput.length < 4) {
          setState(() => _confirmPinInput += val.toString());
          if (_confirmPinInput.length == 4) {
            Future.delayed(Duration(milliseconds: 200), _processCreatePin);
          }
        }
      }
    } else {
      if (_currentStep == 1) {
        if (_currentPinInput.length < 4) {
          setState(() => _currentPinInput += val.toString());
          if (_currentPinInput.length == 4) {
            Future.delayed(Duration(milliseconds: 200), _verifyCurrentPin);
          }
        }
      } else if (_currentStep == 2) {
        if (_newPinInput.length < 4) {
          setState(() => _newPinInput += val.toString());
          if (_newPinInput.length == 4) {
            Future.delayed(Duration(milliseconds: 200), () {
              setState(() => _currentStep = 3);
            });
          }
        }
      } else {
        if (_confirmPinInput.length < 4) {
          setState(() => _confirmPinInput += val.toString());
          if (_confirmPinInput.length == 4) {
            Future.delayed(Duration(milliseconds: 200), _processUpdatePin);
          }
        }
      }
    }
  }

  void _onBackspaceTap() {
    setState(() {
      _errorMessage = null;
    });

    if (widget.mode == PinSetupMode.create) {
      if (_currentStep == 1) {
        if (_newPinInput.isNotEmpty) {
          setState(() => _newPinInput = _newPinInput.substring(0, _newPinInput.length - 1));
        }
      } else {
        if (_confirmPinInput.isNotEmpty) {
          setState(() => _confirmPinInput = _confirmPinInput.substring(0, _confirmPinInput.length - 1));
        }
      }
    } else {
      if (_currentStep == 1) {
        if (_currentPinInput.isNotEmpty) {
          setState(() => _currentPinInput = _currentPinInput.substring(0, _currentPinInput.length - 1));
        }
      } else if (_currentStep == 2) {
        if (_newPinInput.isNotEmpty) {
          setState(() => _newPinInput = _newPinInput.substring(0, _newPinInput.length - 1));
        }
      } else {
        if (_confirmPinInput.isNotEmpty) {
          setState(() => _confirmPinInput = _confirmPinInput.substring(0, _confirmPinInput.length - 1));
        }
      }
    }
  }

  void _verifyCurrentPin() {
    final expectedPin = widget.currentPin ?? "1234";
    if (_currentPinInput == expectedPin) {
      setState(() {
        _currentStep = 2;
      });
    } else {
      setState(() {
        _currentPinInput = "";
        _errorMessage = "El PIN actual es incorrecto";
      });
    }
  }

  Future<void> _processCreatePin() async {
    if (_newPinInput == _confirmPinInput) {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.updateSecurityPin(_newPinInput);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _confirmPinInput = "";
        _errorMessage = "Los PINs no coinciden. Inténtalo de nuevo.";
      });
    }
  }

  Future<void> _processUpdatePin() async {
    if (_newPinInput == _confirmPinInput) {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.updateSecurityPin(_newPinInput);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _confirmPinInput = "";
        _errorMessage = "Los PINs nuevos no coinciden. Inténtalo de nuevo.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: OrtizPalette.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(OrtizRadius.sheet),
          topRight: Radius.circular(OrtizRadius.sheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(OrtizSpace.xxl, OrtizSpace.lg, OrtizSpace.xxl, OrtizSpace.xxl),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: OrtizPalette.line,
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                ),
              ),
            ),
            SizedBox(height: OrtizSpace.xl),
            
            Text(
              _title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: OrtizFontSize.title,
                fontWeight: FontWeight.w900,
                color: AppColors.cardText,
              ),
            ),
            SizedBox(height: OrtizSpace.sm),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: OrtizFontSize.bodySm,
                color: AppColors.cardSubtitleText,
                height: 1.3,
              ),
            ),
            SizedBox(height: OrtizSpace.xxl),

            // Dots indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _activeInput.length;
                return AnimatedContainer(
                  duration: Duration(milliseconds: 150),
                  margin: EdgeInsets.symmetric(horizontal: OrtizSpace.sm),
                  width: 14,
                  height: 14,
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
              )
            else
              SizedBox(height: OrtizSpace.lg),
              
            SizedBox(height: OrtizSpace.lg),

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
                          padding: EdgeInsets.all(OrtizSpace.md),
                        ),
                        child: Text(
                          "Cancelar",
                          style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold),
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
                        padding: EdgeInsets.all(OrtizSpace.md),
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
            height: 52,
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
