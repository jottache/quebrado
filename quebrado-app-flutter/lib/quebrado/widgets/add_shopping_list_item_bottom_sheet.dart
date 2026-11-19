import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../models/market_product.dart';
import '../models/market_shopping_list_item.dart';
import '../widgets/helpers.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';

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
          color: OrtizPalette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(OrtizRadius.sheet)),
        ),
        padding: EdgeInsets.only(
          left: OrtizSpace.lg,
          right: OrtizSpace.lg,
          top: OrtizSpace.lg,
          bottom: bottomInset > 0 ? bottomInset + OrtizSpace.lg : OrtizSpace.xxxl,
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
                    color: OrtizPalette.faint,
                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                  ),
                ),
              ),
              SizedBox(height: OrtizSpace.lg),
              Text(
                "Añadir a la lista",
                style: TextStyle(
                  fontSize: OrtizFontSize.title,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: OrtizSpace.xxl),

              Text(
                "Producto",
                style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.cardText),
              ),
              SizedBox(height: OrtizSpace.xs),
              Text(
                widget.product.name,
                style: TextStyle(fontSize: OrtizFontSize.title, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              SizedBox(height: OrtizSpace.lg),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Cantidad",
                          style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.cardText),
                        ),
                        SizedBox(height: OrtizSpace.xs),
                        TextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [CommaTextInputFormatter()],
                          decoration: InputDecoration(
                            hintText: "1",
                            hintStyle: TextStyle(color: OrtizPalette.muted, fontSize: OrtizFontSize.bodySm),
                            contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                            filled: true,
                            fillColor: OrtizPalette.surfaceHigh,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(OrtizRadius.chip),
                              borderSide: BorderSide(color: AppColors.primary, width: 2),
                            ),
                          ),
                          style: TextStyle(color: AppColors.cardText, fontSize: OrtizFontSize.bodySm),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: OrtizSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Unidad",
                          style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.cardText),
                        ),
                        SizedBox(height: OrtizSpace.xs),
                        if (widget.isNewProduct) ...[
                          DropdownButtonFormField<String>(
                            value: _selectedUnit,
                            hint: Text("Unidad"),
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
                              filled: true,
                              fillColor: OrtizPalette.surfaceHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            dropdownColor: OrtizPalette.surface,
                            style: TextStyle(color: AppColors.cardText, fontSize: OrtizFontSize.bodySm),
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
                            padding: const EdgeInsets.symmetric(vertical: OrtizSpace.md),
                            child: Text(
                              _selectedUnit,
                              style: TextStyle(fontSize: OrtizFontSize.body, color: OrtizPalette.fg),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: OrtizSpace.xxl),
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
                    foregroundColor: OrtizPalette.onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
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
