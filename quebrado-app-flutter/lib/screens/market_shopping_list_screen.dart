import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../models/market_shopping_list.dart';
import '../models/market_shopping_list_item.dart';
import '../models/market_product.dart';
import '../widgets/claymorphic_card.dart';

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

    final newItem = MarketShoppingListItem(
      id: Uuid().v4(),
      listId: widget.listId,
      productId: product.id,
      isChecked: false,
    );

    await appState.addMarketShoppingListItem(newItem);
    _searchController.clear();
    _searchFocusNode.unfocus();
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

    await appState.addMarketProduct(newProduct);
    _addItemToList(newProduct);
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
        actions: [
          if (!list.isActive)
            TextButton.icon(
              onPressed: () async {
                final updated = MarketShoppingList(
                  id: list.id,
                  title: list.title,
                  date: list.date,
                  isActive: true,
                );
                await appState.updateMarketShoppingList(updated);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lista activada para compras.')),
                );
              },
              icon: Icon(Icons.check_circle_outline, color: AppColors.primary, size: 18),
              label: Text(
                "Activar",
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Text(
                    "ACTIVA",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
                              Checkbox(
                                activeColor: AppColors.primary,
                                value: row.item.isChecked,
                                onChanged: (val) async {
                                  if (val != null) {
                                    final updated = MarketShoppingListItem(
                                      id: row.item.id,
                                      listId: row.item.listId,
                                      productId: row.item.productId,
                                      isChecked: val,
                                    );
                                    await appState.updateMarketShoppingListItem(updated);
                                  }
                                },
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      row.product.name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: row.item.isChecked ? Colors.grey : Colors.black87,
                                        decoration: row.item.isChecked
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                      ),
                                    ),
                                    Text(
                                      row.product.category,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
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
