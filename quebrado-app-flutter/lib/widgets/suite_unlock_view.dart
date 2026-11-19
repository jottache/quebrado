import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../quebrado/viewmodels/app_state.dart';
import '../theme/ortiz_tokens.dart';
import 'ortiz/ortiz_empty_state.dart';

/// Pantalla de la ruta `/desbloquear` (`docs/design/rutas.md` §10, P-04
/// revisada el 2026-11-18: el PIN se pide una vez al día al entrar a la app).
///
/// Al primer frame pide el PIN o la biometría con `AppState.verifySecurityAuth`
/// y, si se confirma, avisa con [onUnlocked] (el router marca el día como
/// desbloqueado y vuelve adonde iba la persona). Si cancela, la app sigue
/// bloqueada: no hay adónde ir, así que se queda aquí con un botón para
/// intentarlo de nuevo.
class SuiteUnlockView extends StatefulWidget {
  const SuiteUnlockView({super.key, required this.onUnlocked});

  /// Título del diálogo del PIN (A8: antes decía «Confirmar Transacción»).
  static const String title = 'Desbloquear';

  /// Motivo que se muestra en el diálogo del PIN.
  static const String reason = 'Ingresa tu PIN para entrar a Ortiz';

  final VoidCallback onUnlocked;

  @override
  State<SuiteUnlockView> createState() => _SuiteUnlockViewState();
}

class _SuiteUnlockViewState extends State<SuiteUnlockView> {
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  Future<void> _verify() async {
    if (_asking || !mounted) return;
    setState(() => _asking = true);
    final verified = await context.read<AppState>().verifySecurityAuth(
          context,
          reason: SuiteUnlockView.reason,
          title: SuiteUnlockView.title,
        );
    if (!mounted) return;
    setState(() => _asking = false);
    if (verified) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrtizPalette.bg,
      body: OrtizEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Ortiz está bloqueado',
        message: 'Ingresa tu PIN una vez al día para usar la suite.',
        action: FilledButton(
          onPressed: _asking ? null : _verify,
          child: const Text(SuiteUnlockView.title),
        ),
      ),
    );
  }
}
