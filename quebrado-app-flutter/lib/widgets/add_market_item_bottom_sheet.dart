import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../models/market_item.dart';
import '../models/market_store.dart';
import '../models/market_product.dart';
import '../widgets/add_market_store_bottom_sheet.dart';
import '../widgets/helpers.dart';

class AddMarketItemBottomSheet extends StatefulWidget {
  final String tripId;
  final String? initialStoreId;
  final bool forceStore;

  const AddMarketItemBottomSheet({
    Key? key,
    required this.tripId,
    this.initialStoreId,
    this.forceStore = false,
  }) : super(key: key);

  @override
  _AddMarketItemBottomSheetState createState() => _AddMarketItemBottomSheetState();
}

class _AddMarketItemBottomSheetState extends State<AddMarketItemBottomSheet> {
  final _nameController = TextEditingController();
  final _priceUsdController = TextEditingController();
  final _priceVesController = TextEditingController();
  final _rateController = TextEditingController();
  
  String? _selectedCategory;
  String? _selectedStoreId;

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
    _selectedStoreId = widget.initialStoreId;
    
    final appState = Provider.of<AppState>(context, listen: false);
    _rateController.text = appState.bcvRate.toStringAsFixed(2).replaceAll('.', ',');
    
    _priceUsdController.addListener(_onUsdChanged);
    _priceVesController.addListener(_onVesChanged);
    _rateController.addListener(_onRateChanged);
  }

  bool _isUpdating = false;

  void _onUsdChanged() {
    if (_isUpdating) return;
    final usd = double.tryParse(_priceUsdController.text.replaceAll(',', '.')) ?? 0.0;
    final rate = double.tryParse(_rateController.text.replaceAll(',', '.')) ?? 0.0;
    _isUpdating = true;
    if (usd > 0 && rate > 0) {
      _priceVesController.text = (usd * rate).toStringAsFixed(2).replaceAll('.', ',');
    } else if (_priceUsdController.text.isEmpty) {
      _priceVesController.text = '';
    }
    _isUpdating = false;
  }

  void _onVesChanged() {
    if (_isUpdating) return;
    final ves = double.tryParse(_priceVesController.text.replaceAll(',', '.')) ?? 0.0;
    final rate = double.tryParse(_rateController.text.replaceAll(',', '.')) ?? 0.0;
    _isUpdating = true;
    if (ves > 0 && rate > 0) {
      _priceUsdController.text = (ves / rate).toStringAsFixed(2).replaceAll('.', ',');
    } else if (_priceVesController.text.isEmpty) {
      _priceUsdController.text = '';
    }
    _isUpdating = false;
  }

  void _onRateChanged() {
    if (_isUpdating) return;
    final ves = double.tryParse(_priceVesController.text.replaceAll(',', '.')) ?? 0.0;
    final rate = double.tryParse(_rateController.text.replaceAll(',', '.')) ?? 0.0;
    if (ves > 0 && rate > 0) {
      _isUpdating = true;
      _priceUsdController.text = (ves / rate).toStringAsFixed(2).replaceAll('.', ',');
      _isUpdating = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceUsdController.dispose();
    _priceVesController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _showAddStoreDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AddMarketStoreBottomSheet(
          onStoreAdded: (storeId) {
            setState(() {
              _selectedStoreId = storeId;
            });
          },
        );
      },
    );
  }

  void _saveItem() async {
    if (_nameController.text.trim().isEmpty ||
        _selectedCategory == null ||
        _selectedStoreId == null ||
        _priceUsdController.text.isEmpty ||
        _priceVesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor completa todos los campos requeridos')),
      );
      return;
    }

    final usd = double.tryParse(_priceUsdController.text.replaceAll(',', '.')) ?? 0.0;
    final ves = double.tryParse(_priceVesController.text.replaceAll(',', '.')) ?? 0.0;
    final rate = double.tryParse(_rateController.text.replaceAll(',', '.')) ?? 0.0;

    final String productName = _nameController.text.trim();

    final appState = Provider.of<AppState>(context, listen: false);
    
    // Check if the product already exists in the catalogue (case-insensitive)
    final matches = appState.marketProducts.where(
      (p) => p.name.toLowerCase() == productName.toLowerCase()
    );

    String assignedProductId;

    if (matches.isNotEmpty) {
      final existingProduct = matches.first;
      assignedProductId = existingProduct.id;
      bool updated = false;
      
      // Associate with current store if not already present
      if (!existingProduct.storeIds.contains(_selectedStoreId!)) {
        existingProduct.storeIds.add(_selectedStoreId!);
        updated = true;
      }
      
      // Update reference price
      if (existingProduct.referencePriceUSD != usd) {
        existingProduct.referencePriceUSD = usd;
        updated = true;
      }
      
      // Update category if different
      if (existingProduct.category != _selectedCategory!) {
        existingProduct.category = _selectedCategory!;
        updated = true;
      }
      
      if (updated) {
        await appState.updateMarketProduct(existingProduct);
      }
    } else {
      // Create and save new product to catalogue
      assignedProductId = Uuid().v4();
      final newProduct = MarketProduct(
        id: assignedProductId,
        name: productName,
        category: _selectedCategory!,
        storeIds: [_selectedStoreId!],
        referencePriceUSD: usd,
      );
      await appState.addMarketProduct(newProduct);
    }

    final item = MarketItem(
      id: Uuid().v4(),
      name: productName,
      category: _selectedCategory!,
      priceUSD: usd,
      priceVES: ves,
      exchangeRateUsed: rate,
      storeId: _selectedStoreId!,
      tripId: widget.tripId,
      productId: assignedProductId,
      date: DateTime.now(),
    );

    appState.addMarketItem(item);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
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
                "Añadir al Mercado",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              
              Text(
                "Nombre del producto",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cardText),
              ),
              SizedBox(height: 4),
              Autocomplete<MarketProduct>(
                displayStringForOption: (option) => option.name,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final storeProducts = appState.marketProducts.where((p) => p.storeIds.contains(_selectedStoreId)).toList();
                  if (textEditingValue.text.isEmpty) {
                    return storeProducts;
                  }
                  return storeProducts.where((p) => 
                    p.name.toLowerCase().contains(textEditingValue.text.toLowerCase())
                  );
                },
                onSelected: (MarketProduct selection) {
                  _nameController.text = selection.name;
                  setState(() {
                    _selectedCategory = selection.category;
                    if (_selectedCategory != null && !_categories.contains(_selectedCategory)) {
                      _categories.add(_selectedCategory!);
                    }
                    if (selection.referencePriceUSD != null && selection.referencePriceUSD! > 0) {
                      _priceUsdController.text = selection.referencePriceUSD!.toStringAsFixed(2).replaceAll('.', ',');
                      _onUsdChanged();
                    }
                  });
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  // Sincronizar el _nameController con el controller del Autocomplete
                  controller.addListener(() {
                    _nameController.text = controller.text;
                  });
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: "Ej. Cartón de Huevos",
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                      contentPadding: EdgeInsets.all(12),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(fontSize: 13, color: AppColors.cardText),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: MediaQuery.of(context).size.width - 32,
                        constraints: BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              title: Text(option.name, style: TextStyle(fontSize: 13)),
                              subtitle: Text(option.category, style: TextStyle(fontSize: 11)),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 16),
              
              Text(
                "Categoría",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cardText),
              ),
              SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                hint: Text("Seleccionar Categoría"),
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
              ),
              SizedBox(height: 16),
              
              if (!widget.forceStore) ...[
                Text(
                  "Establecimiento",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cardText),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStoreId,
                        hint: Text("Seleccionar"),
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
                        items: appState.marketStores.map((store) {
                          return DropdownMenuItem(
                            value: store.id,
                            child: Text(store.name, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedStoreId = val;
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.add_circle, color: AppColors.primary, size: 40),
                      padding: EdgeInsets.zero,
                      onPressed: _showAddStoreDialog,
                    )
                  ],
                ),
                SizedBox(height: 16),
              ],
              
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Precio (\$)",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cardText),
                        ),
                        SizedBox(height: 4),
                        TextField(
                          controller: _priceUsdController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [CommaTextInputFormatter()],
                          decoration: InputDecoration(
                            hintText: "0.00 \$",
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                            contentPadding: EdgeInsets.all(12),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: TextStyle(fontSize: 13, color: AppColors.cardText),
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
                          "Precio (Bs)",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cardText),
                        ),
                        SizedBox(height: 4),
                        TextField(
                          controller: _priceVesController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [CommaTextInputFormatter()],
                          decoration: InputDecoration(
                            hintText: "0.00 Bs.",
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                            contentPadding: EdgeInsets.all(12),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: TextStyle(fontSize: 13, color: AppColors.cardText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              
              Text(
                "Tasa de cambio usada",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cardText),
              ),
              SizedBox(height: 4),
              TextField(
                controller: _rateController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [CommaTextInputFormatter()],
                decoration: InputDecoration(
                  hintText: "0.00",
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                  contentPadding: EdgeInsets.all(12),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(fontSize: 13, color: AppColors.cardText),
              ),
              SizedBox(height: 24),
              
              ElevatedButton(
                onPressed: _saveItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "Guardar Producto",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
