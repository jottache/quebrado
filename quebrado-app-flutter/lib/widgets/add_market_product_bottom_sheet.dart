import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/market_product.dart';
import '../models/market_store.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveProduct() {
    if (_formKey.currentState!.validate()) {
      final appState = Provider.of<AppState>(context, listen: false);
      
      if (widget.productToEdit == null) {
        final newProduct = MarketProduct(
          id: Uuid().v4(),
          name: _nameController.text.trim(),
          category: _selectedCategory ?? 'Otros',
          storeIds: _selectedStoreIds,
        );
        appState.addMarketProduct(newProduct);
      } else {
        widget.productToEdit!.name = _nameController.text.trim();
        widget.productToEdit!.category = _selectedCategory ?? 'Otros';
        widget.productToEdit!.storeIds = _selectedStoreIds;
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
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Nombre del producto",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (val) => val == null || val.isEmpty ? "Requerido" : null,
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: Text("Seleccionar Categoría"),
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              dropdownColor: Colors.white,
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
            SizedBox(height: 16),
            Text(
              "Se consigue en:",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: appState.marketStores.map((store) {
                final isSelected = _selectedStoreIds.contains(store.id);
                return FilterChip(
                  label: Text(store.name),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withOpacity(0.2),
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
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isEditing ? "GUARDAR CAMBIOS" : "CREAR PRODUCTO",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
