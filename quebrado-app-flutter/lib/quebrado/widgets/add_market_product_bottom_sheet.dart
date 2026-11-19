import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/market_product.dart';
import '../models/market_store.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../widgets/helpers.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

class AddMarketProductBottomSheet extends StatefulWidget {
  final MarketProduct? productToEdit;

  const AddMarketProductBottomSheet({Key? key, this.productToEdit}) : super(key: key);

  @override
  _AddMarketProductBottomSheetState createState() => _AddMarketProductBottomSheetState();
}

class _AddMarketProductBottomSheetState extends State<AddMarketProductBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  String? _selectedCategory;
  List<String> _selectedStoreIds = [];
  late TextEditingController _defaultQuantityController;
  String _selectedUnit = 'un';
  final List<String> _units = ['un', 'kg', 'g', 'L', 'ml', 'paquete'];
  final List<String> _categories = [
    'Proteínas',
    'Vegetales',
    'Víveres',
    'Charcutería',
    'Frutas',
    'Lácteos',
    'Limpieza',
    'Higiene',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.productToEdit?.name ?? '');
    _selectedCategory = widget.productToEdit?.category;
    if (_selectedCategory != null && !_categories.contains(_selectedCategory)) {
      _categories.add(_selectedCategory!);
    }
    _selectedStoreIds = widget.productToEdit?.storeIds.toList() ?? [];
    
    _defaultQuantityController = TextEditingController(
      text: widget.productToEdit != null
          ? (widget.productToEdit!.defaultQuantity.toString().endsWith('.0') 
              ? widget.productToEdit!.defaultQuantity.toInt().toString() 
              : widget.productToEdit!.defaultQuantity.toString())
          : '1',
    );
    if (widget.productToEdit != null && widget.productToEdit!.unit.isNotEmpty) {
      _selectedUnit = widget.productToEdit!.unit;
      if (!_units.contains(_selectedUnit)) {
        _units.add(_selectedUnit);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _defaultQuantityController.dispose();
    super.dispose();
  }

  void _saveProduct() {
    if (_formKey.currentState!.validate()) {
      final appState = Provider.of<AppState>(context, listen: false);
      final qty = double.tryParse(_defaultQuantityController.text.replaceAll(',', '.')) ?? 1.0;
      
      if (widget.productToEdit == null) {
        final newProduct = MarketProduct(
          id: Uuid().v4(),
          name: _nameController.text.trim(),
          category: _selectedCategory ?? 'Otros',
          storeIds: _selectedStoreIds,
          unit: _selectedUnit,
          defaultQuantity: qty,
        );
        appState.addMarketProduct(newProduct);
      } else {
        widget.productToEdit!.name = _nameController.text.trim();
        widget.productToEdit!.category = _selectedCategory ?? 'Otros';
        widget.productToEdit!.storeIds = _selectedStoreIds;
        widget.productToEdit!.unit = _selectedUnit;
        widget.productToEdit!.defaultQuantity = qty;
        appState.updateMarketProduct(widget.productToEdit!);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isEditing = widget.productToEdit != null;

    return Container(
      decoration: BoxDecoration(
        color: OrtizPalette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(OrtizRadius.sheet)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + OrtizSpace.xl,
        top: OrtizSpace.xl,
        left: OrtizSpace.xl,
        right: OrtizSpace.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? "Editar Producto" : "Nuevo Producto",
              style: TextStyle(
                fontSize: OrtizFontSize.title,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: OrtizSpace.xl),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Nombre del producto",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (val) => val == null || val.isEmpty ? "Requerido" : null,
            ),
            SizedBox(height: OrtizSpace.lg),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: Text("Seleccionar Categoría"),
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.md),
              ),
              dropdownColor: OrtizPalette.surface,
              items: _categories.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(cat),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedCategory = val;
                });
              },
              validator: (val) => val == null || val.isEmpty ? "Requerido" : null,
            ),
            SizedBox(height: OrtizSpace.lg),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _defaultQuantityController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [CommaTextInputFormatter()],
                    decoration: InputDecoration(
                      labelText: "Cant. Defecto",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                    ),
                    validator: (val) => val == null || val.isEmpty ? "Requerido" : null,
                  ),
                ),
                SizedBox(width: OrtizSpace.lg),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: "Unidad",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.field)),
                    ),
                    dropdownColor: OrtizPalette.surface,
                    items: _units.map((u) {
                      return DropdownMenuItem(value: u, child: Text(u));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedUnit = val;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: OrtizSpace.lg),
            Text(
              "Se consigue en:",
              style: TextStyle(fontWeight: FontWeight.bold, color: OrtizPalette.muted),
            ),
            SizedBox(height: OrtizSpace.sm),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: appState.marketStores.map((store) {
                final isSelected = _selectedStoreIds.contains(store.id);
                return FilterChip(
                  label: Text(store.name),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primary,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedStoreIds.add(store.id);
                      } else {
                        _selectedStoreIds.remove(store.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            SizedBox(height: OrtizSpace.xxl),
            ElevatedButton(
              onPressed: _saveProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: OrtizSpace.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(OrtizRadius.field),
                ),
              ),
              child: Text(
                isEditing ? "GUARDAR CAMBIOS" : "CREAR PRODUCTO",
                style: TextStyle(color: OrtizPalette.onAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
