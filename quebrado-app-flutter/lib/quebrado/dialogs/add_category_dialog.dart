import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../models/transaction_category.dart';
import 'package:quebrado_app_flutter/theme/ortiz_motion.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';
import '../widgets/helpers.dart';
import '../theme/colors.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
class AddCategoryBottomSheet extends StatefulWidget {
  final TransactionCategoryType initialType;
  final TransactionCategory? editingCategory;

  const AddCategoryBottomSheet({
    super.key,
    required this.initialType,
    this.editingCategory,
  });

  @override
  State<AddCategoryBottomSheet> createState() => _AddCategoryBottomSheetState();
}

class _AddCategoryBottomSheetState extends State<AddCategoryBottomSheet> {
  final _nameController = TextEditingController();
  late TransactionCategoryType _categoryType;
  late String _selectedColorHex;
  late String _selectedIcon;
  String? _selectedParentId;

  final List<String> _icons = [
    "briefcase", "computer", "gift", "trendingup", "creditcard", "wallet",
    "restaurant", "localcafe", "cart", "bag", "car", "home",
    "bolt", "gamecontroller", "heart", "airplane", "tv", "book",
    "musicnote", "medical", "pills", "tag", "ellipsis"
  ];

  @override
  void initState() {
    super.initState();
    if (widget.editingCategory != null) {
      _nameController.text = widget.editingCategory!.name;
      _categoryType = widget.editingCategory!.type;
      _selectedColorHex = widget.editingCategory!.colorHex;
      _selectedIcon = widget.editingCategory!.icon;
      _selectedParentId = widget.editingCategory!.parentId;
    } else {
      _categoryType = widget.initialType;
      _selectedColorHex = AppColors.creationColors[0];
      _selectedIcon = _icons[0];
      _selectedParentId = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveCategory(AppState appState) {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    if (widget.editingCategory != null) {
      widget.editingCategory!.name = name;
      widget.editingCategory!.icon = _selectedIcon;
      widget.editingCategory!.colorHex = _selectedColorHex;
      widget.editingCategory!.type = _categoryType;
      widget.editingCategory!.parentId = _selectedParentId;
      appState.updateCategory(widget.editingCategory!);
    } else {
      appState.addCategory(
        name: name,
        icon: _selectedIcon,
        colorHex: _selectedColorHex,
        type: _categoryType,
        parentId: _selectedParentId,
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final themeColor = parseHexColor(_selectedColorHex);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(OrtizRadius.pill),
          topRight: Radius.circular(OrtizRadius.pill),
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
            SizedBox(height: OrtizSpace.lg),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.editingCategory != null ? "Editar Categoría" : "Crear Categoría",
                  style: const TextStyle(
                    fontSize: OrtizFontSize.title,
                    fontWeight: FontWeight.w900,
                    color: OrtizPalette.fg,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: OrtizSpace.lg),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Preview Icon Card
                    // Vista previa (sin tarjeta)
                    OrtizSection(
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: themeColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                getIconData(_selectedIcon),
                                color: themeColor,
                                size: OrtizIconSize.xl,
                              ),
                            ),
                            const SizedBox(height: OrtizSpace.md),
                            Text(
                              _nameController.text.isEmpty ? "Nueva Categoría" : _nameController.text,
                              style: const TextStyle(
                                fontSize: OrtizFontSize.title,
                                fontWeight: FontWeight.w900,
                                color: AppColors.cardText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Category Details
                    OrtizSection(
                      title: "DETALLES DE LA CATEGORÍA",
                      children: [
                          // Name TextField
                          Text(
                            "Nombre",
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.xs),
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: "Ej. Gimnasio, Freelance Swift...",
                              hintStyle: const TextStyle(color: OrtizPalette.muted, fontSize: OrtizFontSize.bodySm),
                              contentPadding: const EdgeInsets.all(OrtizSpace.md),
                              filled: true,
                              fillColor: OrtizPalette.surfaceHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.field),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: TextStyle(fontSize: OrtizFontSize.body, color: AppColors.cardText),
                            onChanged: (_) => setState(() {}),
                          ),
                          SizedBox(height: OrtizSpace.lg),

                          // Type Picker
                          Text(
                            "Tipo de Movimiento",
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.xs),
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
                                    onTap: () => setState(() => _categoryType = TransactionCategoryType.income),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                                      decoration: BoxDecoration(
                                        color: _categoryType == TransactionCategoryType.income
                                            ? AppColors.nestedTabActiveBg
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "Ingreso",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: OrtizFontSize.bodySm,
                                          color: _categoryType == TransactionCategoryType.income
                                              ? AppColors.nestedTabActiveText
                                              : AppColors.nestedTabInactiveText,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _categoryType = TransactionCategoryType.expense),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.sm),
                                      decoration: BoxDecoration(
                                        color: _categoryType == TransactionCategoryType.expense
                                            ? AppColors.nestedTabActiveBg
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "Gasto",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: OrtizFontSize.bodySm,
                                          color: _categoryType == TransactionCategoryType.expense
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
                          SizedBox(height: OrtizSpace.lg),

                          // Parent Category Picker
                          Text(
                            "Categoría Padre (Opcional)",
                            style: TextStyle(
                              fontSize: OrtizFontSize.bodySm,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.md),
                            decoration: BoxDecoration(
                              color: OrtizPalette.surfaceHigh,
                              borderRadius: BorderRadius.circular(OrtizRadius.field),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                isExpanded: true,
                                value: _selectedParentId,
                                hint: Text("Ninguna", style: TextStyle(fontSize: OrtizFontSize.body, color: AppColors.cardText)),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text("Ninguna", style: TextStyle(fontSize: OrtizFontSize.body, color: AppColors.cardText)),
                                  ),
                                  ...appState.getParentCategories(_categoryType)
                                    .where((c) => c.id != widget.editingCategory?.id)
                                    .map((cat) {
                                    return DropdownMenuItem<String?>(
                                      value: cat.id,
                                      child: Text(cat.name, style: TextStyle(fontSize: OrtizFontSize.body, color: AppColors.cardText)),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedParentId = val;
                                  });
                                },
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Color selection
                    OrtizSection(
                      title: "SELECCIONA UN COLOR",
                      children: [
                          Wrap(
                            spacing: OrtizSpace.md,
                            runSpacing: OrtizSpace.md,
                            alignment: WrapAlignment.center,
                            children: AppColors.creationColors.map((colorHex) {
                              final isSelected = _selectedColorHex == colorHex;
                              final color = parseHexColor(colorHex);
                              return GestureDetector(
                                onTap: () => setState(() => _selectedColorHex = colorHex),
                                child: AnimatedContainer(
                                  duration: OrtizMotion.of(context, OrtizMotion.fast),
                                  curve: OrtizMotion.ease,
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? OrtizPalette.fg : Colors.transparent,
                                      width: isSelected ? 2.5 : 0,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),

                    // Icon selection
                    OrtizSection(
                      title: "SELECCIONA UN ICONO",
                      children: [
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.0,
                            ),
                            itemCount: _icons.length,
                            itemBuilder: (context, index) {
                              final icon = _icons[index];
                              final isSelected = _selectedIcon == icon;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedIcon = icon),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? themeColor : themeColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    getIconData(icon),
                                    color: isSelected ? OrtizPalette.onAccent : themeColor,
                                    size: OrtizIconSize.md,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: OrtizSpace.sm),
                  ],
                ),
              ),
            ),
            SizedBox(height: OrtizSpace.md),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancelar",
                      style: const TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold, color: OrtizPalette.muted),
                    ),
                  ),
                ),
                SizedBox(width: OrtizSpace.md),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: OrtizPalette.onAccent,
                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                    ),
                    onPressed: _nameController.text.trim().isEmpty
                        ? null
                        : () => _saveCategory(appState),
                    child: Text(
                      widget.editingCategory != null ? "Guardar" : "Crear",
                      style: TextStyle(fontSize: OrtizFontSize.body, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
