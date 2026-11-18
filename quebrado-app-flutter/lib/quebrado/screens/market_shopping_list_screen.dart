import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../models/market_shopping_list.dart';
import '../models/market_shopping_list_item.dart';
import '../models/market_product.dart';
import '../../widgets/responsive_sheet_helper.dart';
import '../widgets/add_shopping_list_item_bottom_sheet.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

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
    final allProducts = appState.marketProducts;

    final filtered = allProducts.where((p) {
      return p.name.toLowerCase().contains(query.toLowerCase());
    }).toList();

    setState(() {
      _searchQuery = query;
      _suggestions = filtered;
    });
  }

  void _addItemToList(MarketProduct product) {
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

    showResponsiveSheet(
      context: context,
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

    showResponsiveSheet(
      context: context,
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
            padding: const EdgeInsets.all(OrtizSpace.lg),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: "Escribe un producto para agregar...",
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: OrtizPalette.muted),
                            tooltip: 'Limpiar',
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                  ),
                ),
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(height: OrtizSpace.sm),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: OrtizPalette.surface,
                      borderRadius: BorderRadius.circular(OrtizRadius.menu),
                      border: Border.all(color: OrtizPalette.line, width: OrtizStroke.hairline),
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
                ? const OrtizEmptyState(
                    icon: Icons.shopping_basket_outlined,
                    title: "La lista está vacía.",
                    message: "Agrega productos en el buscador de arriba.",
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg),
                    itemCount: mappedItems.length,
                    separatorBuilder: (context, index) => const Divider(height: OrtizStroke.hairline),
                    itemBuilder: (context, index) {
                      final row = mappedItems[index];
                      final qty = row.item.quantity.toString().endsWith('.0')
                          ? row.item.quantity.toInt().toString()
                          : row.item.quantity.toStringAsFixed(2);
                      return ortizStaggered(
                        context,
                        index,
                        OrtizListRow(
                          title: row.product.name,
                          subtitle: "${row.product.category} · $qty ${row.product.unit}",
                          trailing: IconButton(
                            icon: const Icon(Icons.close, color: OrtizPalette.muted, size: OrtizIconSize.md),
                            tooltip: 'Quitar de la lista',
                            onPressed: () async {
                              await appState.deleteMarketShoppingListItem(row.item.id);
                            },
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
