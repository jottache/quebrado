import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../widgets/add_market_item_bottom_sheet.dart';
import '../widgets/claymorphic_background.dart';
import '../widgets/claymorphic_card.dart';
import '../models/market_shopping_list.dart';
import '../models/market_shopping_list_item.dart';
import '../models/market_product.dart';
import '../models/market_item.dart';
import 'package:uuid/uuid.dart';

class MarketTripStoreScreen extends StatelessWidget {
  final String tripId;
  final String storeId;

  const MarketTripStoreScreen({
    Key? key,
    required this.tripId,
    required this.storeId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final tripMatches = appState.marketTrips.where((t) => t.id == tripId);
    final storeMatches = appState.marketStores.where((s) => s.id == storeId);
    
    if (tripMatches.isEmpty || storeMatches.isEmpty) {
      return const Scaffold(backgroundColor: AppColors.background);
    }
    
    final trip = tripMatches.first;
    final store = storeMatches.first;
    
    final itemsInStore = appState.marketItems.where(
      (i) => i.tripId == tripId && i.storeId == storeId
    ).toList();
    
    final totalUSD = itemsInStore.fold(0.0, (sum, i) => sum + i.priceUSD);
    final totalVES = itemsInStore.fold(0.0, (sum, i) => sum + i.priceVES);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primary),
        title: Text(
          store.name,
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (trip.isActive)
            IconButton(
              icon: Icon(Icons.playlist_add_check, color: AppColors.primary),
              onPressed: () {
                _showShoppingListBottomSheet(context, appState, tripId, storeId);
              },
            ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red[300]),
            onPressed: () {
              _confirmDeleteStore(context, appState, itemsInStore);
            },
          ),
        ],
      ),
      body: ClaymorphicBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ClaymorphicCard(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "TOTAL TIENDA",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.cardSubtitleText,
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "\$${totalUSD.toStringAsFixed(2)}",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "Bs ${totalVES.toStringAsFixed(2)}",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: itemsInStore.isEmpty
                  ? Center(
                      child: Text(
                        "No has añadido productos de esta tienda.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : _buildItemsList(context, appState, itemsInStore, tripId, storeId),
            ),
          ],
        ),
      ),
      bottomNavigationBar: trip.isActive ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AddMarketItemBottomSheet(
                  tripId: tripId,
                  initialStoreId: storeId,
                  forceStore: true,
                ),
              );
            },
            icon: Icon(Icons.add, size: 20),
            label: Text(
              "AGREGAR PRODUCTO",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                fontSize: 12,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ) : null,
    );
  }

  Widget _buildItemsList(BuildContext context, AppState appState, List<MarketItem> items, String tripId, String storeId) {
    final pendingItems = items.where((i) => i.isPending).toList();
    final registeredItems = items.where((i) => !i.isPending).toList();

    List<Widget> listWidgets = [];

    if (pendingItems.isNotEmpty) {
      listWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Text(
            "Pendientes",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
      );
      for (var item in pendingItems) {
        listWidgets.add(_buildPendingItemCard(context, appState, item, tripId, storeId));
      }
    }

    if (registeredItems.isNotEmpty) {
      listWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Text(
            "Registrados",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
      );
      for (var item in registeredItems) {
        listWidgets.add(_buildRegisteredItemCard(context, appState, item));
      }
    }

    return ListView(
      padding: EdgeInsets.only(bottom: 100, top: 0),
      children: listWidgets,
    );
  }

  Widget _buildPendingItemCard(BuildContext context, AppState appState, MarketItem item, String tripId, String storeId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: ClaymorphicCard(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Checkbox(
              activeColor: AppColors.primary,
              value: false,
              onChanged: (val) {
                if (val == true) {
                  // Open AddMarketItemBottomSheet in edit/register mode
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => AddMarketItemBottomSheet(
                      tripId: tripId,
                      initialStoreId: storeId,
                      forceStore: true,
                      pendingItem: item, // we will add this parameter to AddMarketItemBottomSheet
                    ),
                  );
                }
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.cardText,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    item.category,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.cardSubtitleText,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.grey, size: 20),
              onPressed: () {
                _confirmDeleteItem(context, appState, item);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisteredItemCard(BuildContext context, AppState appState, MarketItem item) {
    final qtyStr = item.quantity.toString().endsWith('.0') 
        ? item.quantity.toInt().toString() 
        : item.quantity.toStringAsFixed(2);
        
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: ClaymorphicCard(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fastfood_outlined,
                color: AppColors.cardSubtitleText,
                size: 20,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.cardText,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        "$qtyStr ${item.unit}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "\$${item.priceUSD.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    fontSize: 18,
                  ),
                ),
                Text(
                  "Bs ${item.priceVES.toStringAsFixed(2)}",
                  style: TextStyle(
                    color: AppColors.cardSubtitleText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.red[300], size: 20),
              onPressed: () {
                _confirmDeleteItem(context, appState, item);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showShoppingListBottomSheet(
    BuildContext context,
    AppState appState,
    String tripId,
    String storeId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final lists = appState.shoppingLists;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Cargar Lista de Compras",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Selecciona una lista para cargar sus productos como pendientes en esta sesión.",
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              SizedBox(height: 16),
              if (lists.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      "No tienes ninguna lista de compras creada.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: lists.length,
                  itemBuilder: (context, index) {
                    final list = lists[index];
                    return ListTile(
                      leading: Icon(Icons.list_alt, color: AppColors.primary),
                      title: Text(list.title, style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () async {
                        Navigator.pop(context); // Close sheet
                        
                        // Load items
                        final listItems = appState.shoppingListItems
                            .where((item) => item.listId == list.id)
                            .toList();
                            
                        for (var listItem in listItems) {
                          final product = appState.marketProducts.firstWhere(
                            (p) => p.id == listItem.productId,
                            orElse: () => MarketProduct(
                              id: listItem.productId,
                              name: 'Producto Desconocido',
                              category: 'Otros',
                            ),
                          );
                          
                          final newItem = MarketItem(
                            id: const Uuid().v4(),
                            name: product.name,
                            category: product.category,
                            priceUSD: 0.0,
                            priceVES: 0.0,
                            exchangeRateUsed: appState.bcvRate,
                            storeId: storeId,
                            tripId: tripId,
                            productId: product.id,
                            date: DateTime.now(),
                            isPending: true,
                            quantity: listItem.quantity,
                            unit: product.unit,
                          );
                          await appState.addMarketItem(newItem);
                        }
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lista "${list.title}" cargada con éxito.')),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteStore(BuildContext context, AppState appState, List<MarketItem> itemsInStore) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "¿Eliminar Establecimiento?",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 12),
              Text(
                "Se eliminarán todos los productos registrados en este establecimiento para esta sesión.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancelar", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context); // Close bottom sheet
                        for (var item in itemsInStore) {
                          await appState.deleteMarketItem(item.id);
                        }
                        Navigator.pop(context); // Go back to trip screen
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text("Eliminar", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteItem(BuildContext context, AppState appState, MarketItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "¿Eliminar Producto?",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 12),
              Text(
                "¿Estás seguro que deseas remover ${item.name} de esta sesión?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancelar", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context); // Close bottom sheet
                        await appState.deleteMarketItem(item.id);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text("Eliminar", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
