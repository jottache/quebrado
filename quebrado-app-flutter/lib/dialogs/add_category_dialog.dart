import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/app_state.dart';
import '../models/transaction_category.dart';
import '../widgets/claymorphic_card.dart';
import '../widgets/helpers.dart';
import '../theme/colors.dart';

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
      decoration: BoxDecoration(
        color: Color(0xFFF9F9F5),
        borderRadius: BorderRadius.only(
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
            SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.editingCategory != null ? "Editar Categoría" : "Crear Categoría",
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

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Preview Icon Card
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: themeColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              getIconData(_selectedIcon),
                              color: themeColor,
                              size: 32,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            _nameController.text.isEmpty ? "Nueva Categoría" : _nameController.text,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),

                    // Category Details Card
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "DETALLES DE LA CATEGORÍA",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: 16),

                          // Name TextField
                          Text(
                            "Nombre",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                          SizedBox(height: 6),
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: "Ej. Gimnasio, Freelance Swift...",
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                              contentPadding: EdgeInsets.all(14),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: TextStyle(fontSize: 14, color: AppColors.cardText),
                            onChanged: (_) => setState(() {}),
                          ),
                          SizedBox(height: 16),

                          // Type Picker
                          Text(
                            "Tipo de Movimiento",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                          SizedBox(height: 6),
                          Container(
                            padding: EdgeInsets.all(4.0),
                            decoration: BoxDecoration(
                              color: AppColors.nestedTabTrackBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _categoryType = TransactionCategoryType.income),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _categoryType == TransactionCategoryType.income
                                            ? AppColors.nestedTabActiveBg
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "Ingreso",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
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
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _categoryType == TransactionCategoryType.expense
                                            ? AppColors.nestedTabActiveBg
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "Gasto",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
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
                          SizedBox(height: 16),

                          // Parent Category Picker
                          Text(
                            "Categoría Padre (Opcional)",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardText,
                            ),
                          ),
                          SizedBox(height: 6),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                isExpanded: true,
                                value: _selectedParentId,
                                hint: Text("Ninguna", style: TextStyle(fontSize: 14, color: AppColors.cardText)),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text("Ninguna", style: TextStyle(fontSize: 14, color: AppColors.cardText)),
                                  ),
                                  ...appState.getParentCategories(_categoryType)
                                    .where((c) => c.id != widget.editingCategory?.id)
                                    .map((cat) {
                                    return DropdownMenuItem<String?>(
                                      value: cat.id,
                                      child: Text(cat.name, style: TextStyle(fontSize: 14, color: AppColors.cardText)),
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
                    ),
                    SizedBox(height: 20),

                    // Color selection card
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "SELECCIONA UN COLOR",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: AppColors.creationColors.map((colorHex) {
                              final isSelected = _selectedColorHex == colorHex;
                              final color = parseHexColor(colorHex);
                              return GestureDetector(
                                onTap: () => setState(() => _selectedColorHex = colorHex),
                                child: AnimatedContainer(
                                  duration: Duration(milliseconds: 150),
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? Colors.black87 : Colors.transparent,
                                      width: isSelected ? 2.5 : 0,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: color.withOpacity(0.4),
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            )
                                          ]
                                        : null,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),

                    // Icon selection card
                    ClaymorphicCard(
                      cornerRadius: 24,
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "SELECCIONA UN ICONO",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.cardSubtitleText,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: 16),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
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
                                    color: isSelected ? themeColor : themeColor.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    getIconData(icon),
                                    color: isSelected ? Colors.white : themeColor,
                                    size: 18,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancelar",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _nameController.text.trim().isEmpty
                        ? null
                        : () => _saveCategory(appState),
                    child: Text(
                      widget.editingCategory != null ? "Guardar" : "Crear",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
