import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_artifact_model.dart';
import '../theme/agente_colors.dart';
import '../../diario/viewmodels/diario_state.dart';
import '../../diario/models/diario_template.dart';
import '../../recordatorios/viewmodels/reminders_state.dart';
import '../../recordatorios/models/reminder_model.dart';
import '../../habitos/viewmodels/habitos_state.dart';
import '../../habitos/models/habit_model.dart';
import '../../quebrado/viewmodels/app_state.dart';
import '../../quebrado/models/transaction.dart';
import '../../quebrado/models/currency_type.dart';

class ActionProposalCardView extends StatefulWidget {
  final ChatArtifactModel artifact;

  const ActionProposalCardView({super.key, required this.artifact});

  @override
  State<ActionProposalCardView> createState() => _ActionProposalCardViewState();
}

class _ActionProposalCardViewState extends State<ActionProposalCardView> {
  bool _isProcessing = false;

  String get _action => widget.artifact.metadata['action']?.toString() ?? '';
  String get _status => widget.artifact.metadata['status']?.toString() ?? 'pending';

  Color _getActionColor() {
    switch (_action) {
      case 'create_contact':
      case 'create_diario_entry':
        return const Color(0xFF8B5CF6);
      case 'create_reminder':
        return const Color(0xFFF97316);
      case 'create_habit':
        return const Color(0xFFEC4899);
      case 'create_transaction':
        return const Color(0xFF10B981);
      default:
        return AgenteColors.primary;
    }
  }

  IconData _getActionIcon() {
    switch (_action) {
      case 'create_contact':
        return Icons.person_add_alt_1_rounded;
      case 'create_diario_entry':
        return Icons.edit_note_rounded;
      case 'create_reminder':
        return Icons.alarm_add_rounded;
      case 'create_habit':
        return Icons.track_changes_rounded;
      case 'create_transaction':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.add_task_rounded;
    }
  }

  String _getActionModuleLabel() {
    switch (_action) {
      case 'create_contact':
      case 'create_diario_entry':
        return 'Diario Jottache';
      case 'create_reminder':
        return 'Recordatorios';
      case 'create_habit':
        return 'Hábitos y Rutinas';
      case 'create_transaction':
        return 'Finanzas Quebrado';
      default:
        return 'OrtizApp';
    }
  }

  Future<void> _handleConfirm() async {
    if (_isProcessing || _status != 'pending') return;

    setState(() => _isProcessing = true);

    try {
      final data = Map<String, dynamic>.from(widget.artifact.metadata['data'] ?? {});

      switch (_action) {
        case 'create_diario_entry':
          final diarioState = Provider.of<DiarioState>(context, listen: false);
          final title = data['title']?.toString().trim() ?? 'Nueva entrada';
          final contentText = data['contentText']?.toString().trim() ?? '';
          final contactName = data['contactName']?.toString().trim();
          String? contactId = data['contactId']?.toString().trim();
          final categoryKey = data['category']?.toString().toLowerCase().trim() ?? 'cat_salud';

          // 1. Resolver contacto
          if (contactId == null || contactId.isEmpty) {
            if (contactName != null && contactName.isNotEmpty) {
              final match = diarioState.contacts.where((c) =>
                  c.name.toLowerCase().contains(contactName.toLowerCase()) ||
                  (c.nickname?.toLowerCase().contains(contactName.toLowerCase()) ?? false));
              if (match.isNotEmpty) {
                contactId = match.first.id;
              } else {
                final newContact = await diarioState.addContact(name: contactName);
                contactId = newContact.id;
              }
            } else if (diarioState.contacts.isNotEmpty) {
              contactId = diarioState.contacts.first.id;
            } else {
              final genContact = await diarioState.addContact(name: 'General');
              contactId = genContact.id;
            }
          }

          // 2. Resolver plantilla/modelo opcional si fue indicado
          final templateName = (data['templateName'] ??
                  data['model'] ??
                  data['template'] ??
                  '')
              .toString()
              .trim();

          DiarioTemplate? matchedTemplate;
          if (templateName.isNotEmpty &&
              templateName.toLowerCase() != 'nota simple' &&
              !templateName.toLowerCase().contains('sin modelo')) {
            final lower = templateName.toLowerCase();
            try {
              matchedTemplate = diarioState.templates.firstWhere((t) =>
                  t.name.toLowerCase() == lower ||
                  t.name.toLowerCase().contains(lower) ||
                  lower.contains(t.name.toLowerCase()));
            } catch (_) {}
          }

          // 3. Resolver categoría raíz (preferir siempre categorías principales para evitar subcategorías como tallas)
          final rootCats = diarioState.getRootCategories(contactId);
          final availableCats = diarioState.categories
              .where((c) => c.contactId == null || c.contactId == contactId)
              .toList();

          String categoryId = rootCats.isNotEmpty ? rootCats.first.id : 'cat_salud';

          if (categoryKey.isNotEmpty && categoryKey != 'general') {
            // Prioridad 1: Coincidencia exacta en raíces
            final exactRoot = rootCats.where((c) =>
                c.id.toLowerCase() == categoryKey ||
                c.id.toLowerCase() == 'cat_$categoryKey' ||
                c.name.toLowerCase() == categoryKey);
            if (exactRoot.isNotEmpty) {
              categoryId = exactRoot.first.id;
            } else {
              // Prioridad 2: Raíz que contenga la clave (ej: "salud" -> "cat_salud")
              final partialRoot = rootCats.where((c) =>
                  c.id.toLowerCase().contains(categoryKey) ||
                  c.name.toLowerCase().contains(categoryKey));
              if (partialRoot.isNotEmpty) {
                categoryId = partialRoot.first.id;
              } else {
                // Prioridad 3: Cualquier categoría disponible que coincida exactamente
                final exactAny = availableCats.where((c) =>
                    c.id.toLowerCase() == categoryKey ||
                    c.name.toLowerCase() == categoryKey);
                if (exactAny.isNotEmpty) {
                  categoryId = exactAny.first.id;
                }
              }
            }
          }

          await diarioState.addEntry(
            contactId: contactId,
            categoryId: categoryId,
            templateId: matchedTemplate?.id,
            entryType: matchedTemplate != null ? 'template_instance' : 'simple_text',
            title: title,
            contentText: contentText,
          );
          break;

        case 'create_contact':
          final diarioState = Provider.of<DiarioState>(context, listen: false);
          final name = data['name']?.toString().trim() ?? 'Nuevo Contacto';
          final nickname = data['nickname']?.toString().trim();
          final relationship = data['relationship']?.toString().trim();
          final phone = data['phone']?.toString().trim();
          final notes = data['notes']?.toString().trim();
          DateTime? birthdate;
          if (data['birthdate'] != null) {
            birthdate = DateTime.tryParse(data['birthdate'].toString());
          }

          await diarioState.addContact(
            name: name,
            nickname: nickname,
            relationship: relationship,
            phone: phone,
            birthdate: birthdate,
            notes: notes,
          );
          break;

        case 'create_reminder':
          final remindersState = Provider.of<RemindersState>(context, listen: false);
          final title = data['title']?.toString().trim() ?? 'Nuevo recordatorio';
          final priority = ReminderPriority.fromString(data['priority']?.toString());
          final recurrence = ReminderRecurrence.fromRrule(data['recurrence']?.toString());
          DateTime? dueAt;
          if (data['dueAt'] != null) {
            dueAt = DateTime.tryParse(data['dueAt'].toString());
          }
          final notes = data['notes']?.toString().trim();

          final newReminder = ReminderModel(
            id: const Uuid().v4(),
            title: title,
            priority: priority,
            rrule: recurrence.rruleString,
            dueAt: dueAt ?? DateTime.now().add(const Duration(hours: 2)),
            notes: notes,
          );

          await remindersState.saveReminder(newReminder);
          break;

        case 'create_habit':
          final habitosState = Provider.of<HabitosState>(context, listen: false);
          final title = data['title']?.toString().trim() ?? 'Nuevo hábito';
          final isNegative = data['isNegative'] == true || data['isNegative']?.toString().toLowerCase() == 'true';

          await habitosState.addHabit(
            title: title,
            isNegative: isNegative,
            type: isNegative ? HabitType.negative : HabitType.binary,
            colorHex: isNegative ? '#FF3B30' : '#00FF66',
          );
          break;

        case 'create_transaction':
          final appState = Provider.of<AppState>(context, listen: false);
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final currency = CurrencyType.fromString(data['currency']?.toString() ?? 'usd');
          final type = TransactionType.fromString(data['type']?.toString() ?? 'expense');
          final description = data['description']?.toString() ?? '';

          // Buscar cuenta preferida por nombre o coincidencia de moneda
          String? accountId;
          final accountName = data['accountName']?.toString().toLowerCase();
          if (accountName != null && accountName.isNotEmpty) {
            final match = appState.accounts.where((a) => a.name.toLowerCase().contains(accountName));
            if (match.isNotEmpty) {
              accountId = match.first.id;
            }
          }
          if (accountId == null && appState.accounts.isNotEmpty) {
            final matchCurr = appState.accounts.where((a) => a.currency == currency);
            accountId = matchCurr.isNotEmpty ? matchCurr.first.id : appState.accounts.first.id;
          }

          final tx = Transaction(
            id: const Uuid().v4(),
            date: DateTime.now(),
            amount: amount,
            currency: currency,
            accountId: accountId,
            note: description.isEmpty ? 'Registro creado por Agente Ortiz' : description,
            type: type,
            exchangeRate: appState.bcvRate,
          );

          await appState.addTransaction(tx);
          break;
      }

      setState(() {
        widget.artifact.metadata['status'] = 'confirmed';
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${widget.artifact.title} creado exitosamente.')),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear registro: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleCancel() {
    if (_isProcessing || _status != 'pending') return;

    setState(() {
      widget.artifact.metadata['status'] = 'cancelled';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acción cancelada. No se crearon registros.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getActionColor();
    final summary = widget.artifact.metadata['summary'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(top: 8.0, bottom: 6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _status == 'confirmed'
              ? const Color(0xFF10B981).withOpacity(0.5)
              : _status == 'cancelled'
                  ? const Color(0xFF94A3B8).withOpacity(0.4)
                  : color.withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header con Módulo y Badge de Estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.09),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(_getActionIcon(), size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getActionModuleLabel(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        widget.artifact.title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(),
              ],
            ),
          ),

          // 2. Descripción o Contenido
          if (widget.artifact.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Text(
                widget.artifact.content,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ),

          // 3. Resumen de Campos Detectados
          if (summary.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: summary.map((item) {
                  final label = item['label']?.toString() ?? '';
                  final value = item['value']?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 105,
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            value,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // 4. Barra de Acciones (Confirmar / Negar)
          if (_status == 'pending')
            Container(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _handleCancel,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Negar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 6,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _handleConfirm,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(_isProcessing ? 'Creando...' : 'Confirmar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    switch (_status) {
      case 'confirmed':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
              SizedBox(width: 4),
              Text(
                'Confirmado',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
              ),
            ],
          ),
        );
      case 'cancelled':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel_rounded, color: Color(0xFF64748B), size: 14),
              SizedBox(width: 4),
              Text(
                'Cancelado',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
              ),
            ],
          ),
        );
      case 'pending':
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFCD34D)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 13),
              SizedBox(width: 4),
              Text(
                'Por confirmar',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
              ),
            ],
          ),
        );
    }
  }
}
