import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../models/mobile_payment_recipient.dart';
import '../widgets/claymorphic_background.dart';
import '../theme/colors.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

List<Map<String, String>> venezuelanBanks = [
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
        title: Image.asset(
          'assets/images/quebrado/logo_quebrado.png',
          height: 50,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            tooltip: "Nuevo contacto",
            icon: const Icon(
              Icons.add_circle_rounded,
              color: AppColors.primary,
              size: OrtizIconSize.lg,
            ),
            onPressed: () => _openRecipientFormSheet(context, appState, null),
          ),
        ],
      ),
      body: ClaymorphicBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xl, vertical: OrtizSpace.sm),
              child: Text(
                "Agenda Pago Móvil",
                style: TextStyle(
                  fontSize: OrtizFontSize.title,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cardText,
                ),
              ),
            ),
            // Campo de búsqueda del tema (sin tarjeta alrededor).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: "Buscar por nombre, banco, cédula...",
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                ),
                style: const TextStyle(color: AppColors.cardText),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
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
      return OrtizEmptyState(
        icon: Icons.contact_phone_rounded,
        title: _searchQuery.isEmpty ? "Sin contactos guardados" : "Sin resultados",
        message: _searchQuery.isEmpty
            ? "Registra contactos de Pago Móvil presionando el botón '+' en la esquina superior derecha."
            : "Intenta con un término de búsqueda diferente.",
      );
    }

    // Lista sin tarjetas: filas sobre el fondo separadas por líneas.
    return ListView.separated(
      padding: const EdgeInsets.all(OrtizSpace.lg),
      itemCount: list.length,
      separatorBuilder: (context, index) => const Divider(height: OrtizStroke.hairline),
      itemBuilder: (context, index) {
        final recipient = list[index];

        return OrtizListRow(
          leading: const Icon(Icons.person_rounded, color: AppColors.primary),
          title: recipient.alias,
          subtitle: "${recipient.bankName} (${recipient.bankCode})\n"
              "${recipient.identityCard} • ${recipient.phoneNumber}",
          trailing: const Icon(Icons.chevron_right_rounded, color: OrtizPalette.muted),
          onTap: () => _openRecipientFormSheet(context, appState, recipient),
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
        SnackBar(content: Text("Por favor rellena todos los campos.")),
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
      decoration: const BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(OrtizRadius.sheet),
          topRight: Radius.circular(OrtizRadius.sheet),
        ),
      ),
      padding: EdgeInsets.only(
        left: OrtizSpace.lg,
        right: OrtizSpace.lg,
        top: OrtizSpace.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + OrtizSpace.xl,
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
                  color: OrtizPalette.line,
                  borderRadius: BorderRadius.circular(OrtizRadius.chip),
                ),
              ),
            ),
            const SizedBox(height: OrtizSpace.lg),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? "Editar Destinatario" : "Nuevo Destinatario",
                  style: const TextStyle(
                    fontSize: OrtizFontSize.title,
                    fontWeight: FontWeight.w900,
                    color: OrtizPalette.fg,
                  ),
                ),
                IconButton(
                  tooltip: "Cerrar",
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: OrtizSpace.lg),

            // Scrollable form
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Grupo sin tarjeta, directo sobre la hoja.
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "DETALLES DE PAGO MÓVIL",
                            style: TextStyle(
                              fontSize: OrtizFontSize.caption,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: OrtizSpace.lg),
                          
                          // Alias
                          Text(
                            "Nombre o Alias",
                            style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                          ),
                          SizedBox(height: OrtizSpace.xs),
                          TextField(
                            controller: _aliasController,
                            decoration: InputDecoration(
                              hintText: "Ej. Mamá, Juan Pérez, CANTV",
                              hintStyle: const TextStyle(color: OrtizPalette.muted, fontSize: OrtizFontSize.bodySm),
                              contentPadding: EdgeInsets.all(OrtizSpace.md),
                              filled: true,
                              fillColor: OrtizPalette.surfaceHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: TextStyle(fontSize: OrtizFontSize.body, color: AppColors.cardText),
                          ),
                          SizedBox(height: OrtizSpace.md),

                          // Banco Receptor
                          Text(
                            "Banco Receptor",
                            style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                          ),
                          SizedBox(height: OrtizSpace.xs),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedBankCode,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.md),
                              filled: true,
                              fillColor: OrtizPalette.surfaceHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            dropdownColor: OrtizPalette.surface,
                            style: TextStyle(color: AppColors.cardText, fontSize: OrtizFontSize.body),
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
                          SizedBox(height: OrtizSpace.md),

                          // Cédula o RIF
                          Text(
                            "Cédula de Identidad / RIF",
                            style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                          ),
                          SizedBox(height: OrtizSpace.xs),
                          Row(
                            children: [
                              Container(
                                width: 80,
                                decoration: BoxDecoration(
                                  color: OrtizPalette.surfaceHigh,
                                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: OrtizSpace.md),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedIdPrefix,
                                    dropdownColor: OrtizPalette.surface,
                                    style: TextStyle(color: AppColors.cardText, fontWeight: FontWeight.bold),
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
                              SizedBox(width: OrtizSpace.sm),
                              Expanded(
                                child: TextField(
                                  controller: _idCardController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: "Número de identificación",
                                    hintStyle: const TextStyle(color: OrtizPalette.muted, fontSize: OrtizFontSize.bodySm),
                                    contentPadding: EdgeInsets.all(OrtizSpace.md),
                                    filled: true,
                                    fillColor: OrtizPalette.surfaceHigh,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  style: TextStyle(fontSize: OrtizFontSize.body, color: AppColors.cardText),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: OrtizSpace.md),

                          // Número de Teléfono
                          Text(
                            "Número de Teléfono",
                            style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.bold, color: AppColors.cardText),
                          ),
                          SizedBox(height: OrtizSpace.xs),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: "Ej. 04121234567",
                              hintStyle: const TextStyle(color: OrtizPalette.muted, fontSize: OrtizFontSize.bodySm),
                              contentPadding: EdgeInsets.all(OrtizSpace.md),
                              filled: true,
                              fillColor: OrtizPalette.surfaceHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: TextStyle(fontSize: OrtizFontSize.body, color: AppColors.cardText),
                          ),
                        ],
                    ),
                    const SizedBox(height: OrtizSpace.xxl),

                    // Actions
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: OrtizPalette.onAccent,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: OrtizSpace.lg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(OrtizRadius.field),
                        ),
                      ),
                      onPressed: _saveRecipient,
                      child: Text(
                        isEditing ? "Guardar Cambios" : "Guardar Destinatario",
                        style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (isEditing) ...[
                      SizedBox(height: OrtizSpace.md),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.expense,
                          padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(OrtizRadius.field),
                          ),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.sheet),
                              ),
                              title: Text("¿Eliminar Destinatario?", style: TextStyle(fontWeight: FontWeight.bold)),
                              content: Text(
                                "¿Estás seguro de que deseas eliminar a ${_aliasController.text.trim()} de tus contactos?",
                                style: TextStyle(fontSize: OrtizFontSize.bodySm),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: Text("Cancelar"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(dialogCtx);
                                    _deleteRecipient();
                                  },
                                  style: TextButton.styleFrom(foregroundColor: AppColors.expense),
                                  child: Text("Eliminar"),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: OrtizIconSize.md),
                        label: Text("Eliminar Destinatario", style: TextStyle(fontWeight: FontWeight.bold)),
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
