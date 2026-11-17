import 'package:flutter/material.dart';

/// Aviso que aparece cuando el editor abre con un borrador recuperado.
class DraftRestoredBanner extends StatelessWidget {
  final DateTime savedAt;
  final VoidCallback onDiscard;
  final VoidCallback onDismiss;
  final Color accent;

  const DraftRestoredBanner({
    super.key,
    required this.savedAt,
    required this.onDiscard,
    required this.onDismiss,
    required this.accent,
  });

  static String describeAge(DateTime savedAt, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(savedAt);
    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    final days = diff.inDays;
    return days == 1 ? 'hace 1 día' : 'hace $days días';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('draft_restored_banner'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Recuperamos tu borrador sin guardar (${describeAge(savedAt)}).',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            key: const ValueKey('draft_discard_button'),
            onPressed: onDiscard,
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent, visualDensity: VisualDensity.compact),
            child: const Text('Descartar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            tooltip: 'Ocultar aviso',
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

/// Avisa (sin bloquear) que lo escrito quedó guardado como borrador.
void showDraftSavedSnackBar(ScaffoldMessengerState? messenger, {required Color color}) {
  // Puede llamarse cuando la pantalla ya se desmontó (por ejemplo, al cerrar sesión
  // con el modal abierto): en ese caso no hay dónde mostrarlo y se omite.
  if (messenger == null || !messenger.mounted) return;
  try {
    _showDraftSaved(messenger, color);
  } catch (_) {}
}

/// Avisa que el borrador se descartó (botón Cancelar) y permite recuperarlo.
void showDraftDiscardedSnackBar(ScaffoldMessengerState? messenger, {required VoidCallback onUndo}) {
  if (messenger == null || !messenger.mounted) return;
  try {
    messenger.hideCurrentSnackBar(); // no esperar en cola detrás de otro aviso
    messenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('Borrador descartado.')),
          ],
        ),
        action: SnackBarAction(label: 'Deshacer', textColor: Colors.white, onPressed: onUndo),
        // Con acción, Flutter lo deja fijo por defecto: este se cierra solo
        persist: false,
        backgroundColor: const Color(0xFF475569),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 5),
      ),
    );
  } catch (_) {}
}

void _showDraftSaved(ScaffoldMessengerState messenger, Color color) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: const Row(
        children: [
          Icon(Icons.save_as_outlined, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('Borrador guardado. Al volver a abrir seguirás donde lo dejaste.')),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ),
  );
}
