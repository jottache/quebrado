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
    final trip = appState.marketTrips.firstWhere(
      (t) => t.id == tripId,
      orElse: () => appState.marketTrips.first,
    );
    final store = appState.marketStores.firstWhere(
      (s) => s.id == storeId,
      orElse: () => appState.marketStores.first,
    );
    
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
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Text(
                            "Productos de la Sesión",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.only(bottom: 100, top: 0),
                            itemCount: itemsInStore.length,
                            itemBuilder: (context, index) {
                        final item = itemsInStore[index];
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
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
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
        final activeList = appState.shoppingLists.where((l) => l.isActive).firstOrNull;

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Lista de Compras Activa",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        if (activeList != null)
                          Text(
                            activeList.title,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.cardSubtitleText,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Divider(),
                  Expanded(
                    child: activeList == null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                "No tienes ninguna lista de compras activa.\nActiva una en la pestaña de Listas.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          )
                        : (() {
                            final listItems = appState.shoppingListItems
                                .where((item) => item.listId == activeList.id && !item.isChecked)
                                .toList();

                            if (listItems.isEmpty) {
                              return Center(
                                child: Text(
                                  "¡Todos los productos han sido comprados!",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              );
                            }

                            return ListView.builder(
                              controller: scrollController,
                              itemCount: listItems.length,
                              itemBuilder: (context, index) {
                                final item = listItems[index];
                                final product = appState.marketProducts.firstWhere(
                                  (p) => p.id == item.productId,
                                  orElse: () => MarketProduct(
                                    id: '',
                                    name: 'Producto Desconocido',
                                    category: 'Otros',
                                  ),
                                );

                                return ListTile(
                                  title: Text(product.name, style: TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(product.category),
                                  trailing: TextButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context); // Close lists sheet
                                      _showRequestPriceBottomSheet(
                                        context,
                                        appState,
                                        tripId,
                                        storeId,
                                        product,
                                        item,
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      backgroundColor: AppColors.primary.withOpacity(0.1),
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    icon: Icon(Icons.add_shopping_cart, size: 16, color: AppColors.primary),
                                    label: Text(
                                      "Agregar",
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          })(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRequestPriceBottomSheet(
    BuildContext context,
    AppState appState,
    String tripId,
    String storeId,
    MarketProduct product,
    MarketShoppingListItem listItem,
  ) {
    final usdController = TextEditingController();
    final vesController = TextEditingController();
    final rate = appState.bcvRate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        double priceUSD = 0.0;
        double priceVES = 0.0;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
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
                      "Comprar ${product.name}",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Ingresa el precio de este producto para agregarlo al carrito.",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: usdController,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: "Precio USD (\$)",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                            onChanged: (val) {
                              final usd = double.tryParse(val) ?? 0.0;
                              priceUSD = usd;
                              priceVES = usd * rate;
                              vesController.text = priceVES > 0 ? priceVES.toStringAsFixed(2) : '';
                            },
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: vesController,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: "Precio VES (Bs)",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                            onChanged: (val) {
                              final ves = double.tryParse(val) ?? 0.0;
                              priceVES = ves;
                              priceUSD = rate > 0 ? ves / rate : 0.0;
                              usdController.text = priceUSD > 0 ? priceUSD.toStringAsFixed(2) : '';
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Tasa de cambio usada: 1 \$ = ${rate.toStringAsFixed(2)} Bs",
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (priceUSD > 0) {
                            // Create market item
                            final newItem = MarketItem(
                              id: Uuid().v4(),
                              name: product.name,
                              category: product.category,
                              priceUSD: priceUSD,
                              priceVES: priceVES,
                              exchangeRateUsed: rate,
                              storeId: storeId,
                              tripId: tripId,
                              date: DateTime.now(),
                            );
                            await appState.addMarketItem(newItem);

                            // Check off the shopping list item
                            final updatedItem = MarketShoppingListItem(
                              id: listItem.id,
                              listId: listItem.listId,
                              productId: listItem.productId,
                              isChecked: true,
                            );
                            await appState.updateMarketShoppingListItem(updatedItem);

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('"${product.name}" agregado con éxito.')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text("Agregar al Carrito"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
