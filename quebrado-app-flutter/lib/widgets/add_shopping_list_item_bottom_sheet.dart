import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../models/market_product.dart';
import '../models/market_shopping_list_item.dart';
import '../widgets/helpers.dart';

class AddShoppingListItemBottomSheet extends StatefulWidget {
  final MarketProduct product;
  final bool isNewProduct;
  final String listId;

  const AddShoppingListItemBottomSheet({
    Key? key,
    required this.product,
    required this.isNewProduct,
    required this.listId,
  }) : super(key: key);

  @override
  _AddShoppingListItemBottomSheetState createState() => _AddShoppingListItemBottomSheetState();
}

class _AddShoppingListItemBottomSheetState extends State<AddShoppingListItemBottomSheet> {
  late TextEditingController _quantityController;
  String _selectedUnit = 'un';
  final List<String> _units = ['un', 'kg', 'g', 'L', 'ml', 'paquete'];

  @override
  void initState() {
    super.initState();
    if (!widget.isNewProduct && widget.product.unit.isNotEmpty) {
      _selectedUnit = widget.product.unit;
      if (!_units.contains(_selectedUnit)) {
        _units.add(_selectedUnit);
      }
    }
    _quantityController = TextEditingController(
      text: widget.product.defaultQuantity.toString().endsWith('.0') 
          ? widget.product.defaultQuantity.toInt().toString() 
          : widget.product.defaultQuantity.toString()
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _save() async {
    final qty = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 1.0;

    final appState = Provider.of<AppState>(context, listen: false);

    if (widget.isNewProduct) {
      widget.product.unit = _selectedUnit;
      await appState.addMarketProduct(widget.product);
    } else {
      // If the unit was changed for an existing product (though UI might disable it, 
      // if we allow it we would update here). But we are hiding the dropdown for existing.
    }

    final newItem = MarketShoppingListItem(
      id: Uuid().v4(),
      listId: widget.listId,
      productId: widget.product.id,
      isChecked: false,
      quantity: qty,
    );

    await appState.addMarketShoppingListItem(newItem);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: bottomInset > 0 ? bottomInset + 16 : 32,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                "Añadir a la lista",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),

              Text(
                "Producto",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cardText),
              ),
              SizedBox(height: 4),
              Text(
                widget.product.name,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Cantidad",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cardText),
                        ),
                        SizedBox(height: 4),
                        TextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [CommaTextInputFormatter()],
                          decoration: InputDecoration(
                            hintText: "1",
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.primary, width: 2),
                            ),
                          ),
                          style: TextStyle(color: AppColors.cardText, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Unidad",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cardText),
                        ),
                        SizedBox(height: 4),
                        if (widget.isNewProduct) ...[
                          DropdownButtonFormField<String>(
                            value: _selectedUnit,
                            hint: Text("Unidad"),
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            dropdownColor: Colors.white,
                            style: TextStyle(color: AppColors.cardText, fontSize: 13),
                            items: _units.map((u) {
                              return DropdownMenuItem(
                                value: u,
                                child: Text(u),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedUnit = val;
                                });
                              }
                            },
                          ),
                        ] else ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              _selectedUnit,
                              style: TextStyle(fontSize: 15, color: Colors.grey[800]),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (_quantityController.text.isNotEmpty) {
                      _save();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text("Añadir a la lista"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
