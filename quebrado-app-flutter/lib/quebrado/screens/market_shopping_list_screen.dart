import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../models/market_shopping_list.dart';
import '../models/market_shopping_list_item.dart';
import '../models/market_product.dart';
import '../widgets/claymorphic_card.dart';
import '../widgets/add_shopping_list_item_bottom_sheet.dart';

class MarketShoppingListScreen extends StatefulWidget {
  final String listId;

  const MarketShoppingListScreen({required this.listId});

  @override
  _MarketShoppingListScreenState createState() => _MarketShoppingListScreenState();
}

class _MarketShoppingListScreenState extends State<MarketShoppingListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<MarketProduct> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _suggestions = [];
      });
      return;
    }

    final appState = Provider.of<AppState>(context, listen: false);
    final filtered = appState.marketProducts
        .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    setState(() {
      _searchQuery = query;
      _suggestions = filtered;
    });
  }

  void _addItemToList(MarketProduct product) async {
    final appState = Provider.of<AppState>(context, listen: false);
    
    // Check if product is already in this list
    final alreadyInList = appState.shoppingListItems.any(
      (item) => item.listId == widget.listId && item.productId == product.id,
    );

    if (alreadyInList) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${product.name}" ya está en la lista.')),
      );
      _searchController.clear();
      _searchFocusNode.unfocus();
      return;
    }

    _searchController.clear();
    _searchFocusNode.unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddShoppingListItemBottomSheet(
        product: product,
        isNewProduct: false,
        listId: widget.listId,
      ),
    );
  }

  void _addNewProductAndAddToList() async {
    final name = _searchController.text.trim();
    if (name.isEmpty) return;

    final appState = Provider.of<AppState>(context, listen: false);

    // Create dynamic product in catalog
    final newProduct = MarketProduct(
      id: Uuid().v4(),
      name: name,
      category: 'Otros',
      storeIds: [],
    );

    _searchController.clear();
    _searchFocusNode.unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddShoppingListItemBottomSheet(
        product: newProduct,
        isNewProduct: true,
        listId: widget.listId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final list = appState.shoppingLists.firstWhere(
      (l) => l.id == widget.listId,
      orElse: () => MarketShoppingList(
        id: '',
        title: 'Lista no encontrada',
        date: DateTime.now(),
        isActive: false,
      ),
    );

    if (list.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text("Error")),
        body: Center(child: Text("Lista de compras no encontrada.")),
      );
    }

    // Filter items belonging to this list
    final listItems = appState.shoppingListItems
        .where((item) => item.listId == widget.listId)
        .toList();

    // Map items to products
    final mappedItems = listItems.map((item) {
      final product = appState.marketProducts.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => MarketProduct(id: '', name: 'Producto Desconocido', category: 'Otros'),
      );
      return _ShoppingListRowModel(item: item, product: product);
    }).toList();

    // Sort: unchecked first, checked at the bottom
    mappedItems.sort((a, b) {
      if (a.item.isChecked == b.item.isChecked) {
        return a.product.name.compareTo(b.product.name);
      }
      return a.item.isChecked ? 1 : -1;
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primary),
        title: Text(
          list.title,
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search & Add Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ClaymorphicCard(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: "Escribe un producto para agregar...",
                      prefixIcon: Icon(Icons.search, color: AppColors.primary),
                      border: InputBorder.none,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Container(
                    constraints: BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        // Dynamic suggestion to create the product if it doesn't match exactly
                        if (!_suggestions.any((p) => p.name.toLowerCase() == _searchQuery.toLowerCase()))
                          ListTile(
                            leading: Icon(Icons.add, color: AppColors.primary),
                            title: Text('Crear "${_searchQuery}" en catálogo'),
                            onTap: _addNewProductAndAddToList,
                          ),
                        ..._suggestions.map((product) {
                          return ListTile(
                            title: Text(product.name),
                            subtitle: Text(product.category),
                            onTap: () => _addItemToList(product),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // List Items
          Expanded(
            child: mappedItems.isEmpty
                ? Center(
                    child: Text(
                      "La lista está vacía.\nAgrega productos en el buscador de arriba.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: mappedItems.length,
                    itemBuilder: (context, index) {
                      final row = mappedItems[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ClaymorphicCard(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      row.product.name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      row.product.category,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "${row.item.quantity.toString().endsWith('.0') ? row.item.quantity.toInt() : row.item.quantity.toStringAsFixed(2)} ${row.product.unit}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.grey, size: 20),
                                onPressed: () async {
                                  await appState.deleteMarketShoppingListItem(row.item.id);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingListRowModel {
  final MarketShoppingListItem item;
  final MarketProduct product;

  _ShoppingListRowModel({required this.item, required this.product});
}
