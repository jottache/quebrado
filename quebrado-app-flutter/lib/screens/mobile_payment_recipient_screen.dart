import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../models/mobile_payment_recipient.dart';
import '../widgets/claymorphic_background.dart';
import '../widgets/claymorphic_card.dart';
import '../theme/colors.dart';

const List<Map<String, String>> venezuelanBanks = [
  {"code": "0102", "name": "Banco de Venezuela"},
  {"code": "0134", "name": "Banesco"},
  {"code": "0105", "name": "Banco Mercantil"},
  {"code": "0108", "name": "BBVA Provincial"},
  {"code": "0172", "name": "Bancamiga"},
  {"code": "0114", "name": "Bancaribe"},
  {"code": "0191", "name": "Banco Nacional de Crédito BNC"},
  {"code": "0115", "name": "Banco Exterior"},
  {"code": "0128", "name": "Banco Caroní"},
  {"code": "0151", "name": "Fondo Común BFC"},
  {"code": "0163", "name": "Banco del Tesoro"},
  {"code": "0168", "name": "Bancrecer"},
  {"code": "0169", "name": "Mi Banco"},
  {"code": "0174", "name": "Banplus"},
  {"code": "0175", "name": "Banco Bicentenario"},
  {"code": "0177", "name": "Banfanb"},
  {"code": "0178", "name": "Banco Activo"},
];

class MobilePaymentRecipientScreen extends StatefulWidget {
  const MobilePaymentRecipientScreen({super.key});

  @override
  State<MobilePaymentRecipientScreen> createState() => _MobilePaymentRecipientScreenState();
}

class _MobilePaymentRecipientScreenState extends State<MobilePaymentRecipientScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MobilePaymentRecipient> _getFilteredRecipients(List<MobilePaymentRecipient> list) {
    if (_searchQuery.isEmpty) return list;
    final query = _searchQuery.toLowerCase();
    return list.where((r) {
      return r.alias.toLowerCase().contains(query) ||
          r.bankName.toLowerCase().contains(query) ||
          r.identityCard.toLowerCase().contains(query) ||
          r.phoneNumber.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final recipients = _getFilteredRecipients(appState.recipients);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 0),
          child: Image.asset(
            'assets/images/quebrado.png',
            height: 50,
            fit: BoxFit.contain,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_rounded,
              color: AppColors.primary,
              size: 28,
            ),
            onPressed: () => _openRecipientFormSheet(context, appState, null),
          ),
        ],
      ),
      body: ClaymorphicBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Text(
                "Agenda Pago Móvil",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cardText,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ClaymorphicCard(
                cornerRadius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: "Buscar por nombre, banco, cédula...",
                    border: InputBorder.none,
                    icon: Icon(Icons.search_rounded, color: AppColors.primary),
                  ),
                  style: const TextStyle(fontSize: 14, color: AppColors.cardText),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
            ),
            Expanded(
              child: _buildRecipientList(context, appState, recipients),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientList(
    BuildContext context,
    AppState appState,
    List<MobilePaymentRecipient> list,
  ) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.contact_phone_rounded, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isEmpty ? "Sin contactos guardados" : "Sin resultados",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isEmpty
                    ? "Registra contactos de Pago Móvil presionando el botón '+' en la esquina superior derecha."
                    : "Intenta con un término de búsqueda diferente.",
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final recipient = list[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: GestureDetector(
            onTap: () => _openRecipientFormSheet(context, appState, recipient),
            child: ClaymorphicCard(
              cornerRadius: 18,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              backgroundColor: AppColors.getAlternateCardColor(index),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipient.alias,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cardText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${recipient.bankName} (${recipient.bankCode})",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${recipient.identityCard} • ${recipient.phoneNumber}",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openRecipientFormSheet(
    BuildContext context,
    AppState appState,
    MobilePaymentRecipient? recipient,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecipientFormBottomSheet(
        editingRecipient: recipient,
        appState: appState,
      ),
    );
  }
}

class _RecipientFormBottomSheet extends StatefulWidget {
  final MobilePaymentRecipient? editingRecipient;
  final AppState appState;

  const _RecipientFormBottomSheet({
    this.editingRecipient,
    required this.appState,
  });

  @override
  State<_RecipientFormBottomSheet> createState() => _RecipientFormBottomSheetState();
}

class _RecipientFormBottomSheetState extends State<_RecipientFormBottomSheet> {
  final _aliasController = TextEditingController();
  final _idCardController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedIdPrefix = "V";
  String? _selectedBankCode;

  @override
  void initState() {
    super.initState();
    final r = widget.editingRecipient;
    if (r != null) {
      _aliasController.text = r.alias;
      _phoneController.text = r.phoneNumber;
      
      // Parse prefix and card number (e.g. V-12345678)
      final parts = r.identityCard.split('-');
      if (parts.length >= 2) {
        _selectedIdPrefix = parts[0];
        _idCardController.text = parts.sublist(1).join('-');
      } else {
        _idCardController.text = r.identityCard;
      }
      
      _selectedBankCode = r.bankCode;
    } else {
      _selectedBankCode = venezuelanBanks.first["code"];
    }
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _idCardController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _saveRecipient() {
    final alias = _aliasController.text.trim();
    final idNum = _idCardController.text.trim();
    final phone = _phoneController.text.trim();
    final bankCode = _selectedBankCode;

    if (alias.isEmpty || idNum.isEmpty || phone.isEmpty || bankCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor rellena todos los campos.")),
      );
      return;
    }

    final formattedIdCard = "$_selectedIdPrefix-$idNum";
    final bankName = venezuelanBanks.firstWhere(
      (b) => b["code"] == bankCode,
      orElse: () => {"code": bankCode, "name": "Banco desconocido"},
    )["name"]!;

    if (widget.editingRecipient != null) {
      final updated = MobilePaymentRecipient(
        id: widget.editingRecipient!.id,
        alias: alias,
        bankCode: bankCode,
        bankName: bankName,
        identityCard: formattedIdCard,
        phoneNumber: phone,
      );
      widget.appState.updateRecipient(updated);
    } else {
      widget.appState.addRecipient(
        alias: alias,
        bankCode: bankCode,
        bankName: bankName,
        identityCard: formattedIdCard,
        phoneNumber: phone,
      );
    }

    Navigator.pop(context);
  }

  void _deleteRecipient() {
    if (widget.editingRecipient != null) {
      widget.appState.deleteRecipient(widget.editingRecipient!.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editingRecipient != null;

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
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
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

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? "Editar Destinatario" : "Nuevo Destinatario",
                  style: const TextStyle(
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

            // Scrollable form
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "DETALLES DE PAGO MÓVIL",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Alias
                          const Text(
                            "Nombre o Alias",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cardText),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _aliasController,
                            decoration: InputDecoration(
                              hintText: "Ej. Mamá, Juan Pérez, CANTV",
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                              contentPadding: const EdgeInsets.all(14),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(fontSize: 14, color: AppColors.cardText),
                          ),
                          const SizedBox(height: 14),

                          // Banco Receptor
                          const Text(
                            "Banco Receptor",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cardText),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedBankCode,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            dropdownColor: Colors.white,
                            style: const TextStyle(color: AppColors.cardText, fontSize: 14),
                            items: venezuelanBanks.map((b) {
                              return DropdownMenuItem<String>(
                                value: b["code"],
                                child: Text(
                                  "${b["name"]} (${b["code"]})",
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (code) {
                              setState(() => _selectedBankCode = code);
                            },
                          ),
                          const SizedBox(height: 14),

                          // Cédula o RIF
                          const Text(
                            "Cédula de Identidad / RIF",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cardText),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedIdPrefix,
                                    dropdownColor: Colors.white,
                                    style: const TextStyle(color: AppColors.cardText, fontWeight: FontWeight.bold),
                                    items: ["V", "E", "J", "G"].map((prefix) {
                                      return DropdownMenuItem<String>(
                                        value: prefix,
                                        child: Text(prefix),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selectedIdPrefix = val);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _idCardController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: "Número de identificación",
                                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                                    contentPadding: const EdgeInsets.all(14),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 14, color: AppColors.cardText),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Número de Teléfono
                          const Text(
                            "Número de Teléfono",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cardText),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: "Ej. 04121234567",
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                              contentPadding: const EdgeInsets.all(14),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(fontSize: 14, color: AppColors.cardText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _saveRecipient,
                      child: Text(
                        isEditing ? "Guardar Cambios" : "Guardar Destinatario",
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (isEditing) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.expense,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              title: const Text("¿Eliminar Destinatario?", style: TextStyle(fontWeight: FontWeight.bold)),
                              content: Text(
                                "¿Estás seguro de que deseas eliminar a ${_aliasController.text.trim()} de tus contactos?",
                                style: const TextStyle(fontSize: 13),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: const Text("Cancelar"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(dialogCtx);
                                    _deleteRecipient();
                                  },
                                  style: TextButton.styleFrom(foregroundColor: AppColors.expense),
                                  child: const Text("Eliminar"),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text("Eliminar Destinatario", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
