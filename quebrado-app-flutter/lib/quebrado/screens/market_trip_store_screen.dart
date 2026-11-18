import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/responsive_sheet_helper.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../widgets/add_market_item_bottom_sheet.dart';
import '../widgets/claymorphic_background.dart';
import '../widgets/helpers.dart';
import '../models/market_product.dart';
import '../models/market_item.dart';
import 'package:uuid/uuid.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

String _formatBsShort(double v) => "Bs ${v.toStringAsFixed(2)}";

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
        iconTheme: const IconThemeData(color: AppColors.primary),
        title: Text(
          store.name,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (trip.isActive)
            IconButton(
              icon: const Icon(Icons.playlist_add_check, color: AppColors.primary),
              tooltip: 'Cargar lista de compras',
              onPressed: () {
                _showShoppingListBottomSheet(context, appState, tripId, storeId);
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: OrtizPalette.bad),
            tooltip: 'Eliminar establecimiento',
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
              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "TOTAL TIENDA",
                          style: OrtizType.caption.copyWith(
                            fontWeight: FontWeight.w900,
                            color: OrtizPalette.muted,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: OrtizSpace.xxs),
                        OrtizAmount(
                          value: totalUSD,
                          currencySymbol: '\$',
                          format: formatUSD,
                          style: OrtizType.amountLg,
                        ),
                      ],
                    ),
                  ),
                  OrtizAmount(
                    value: totalVES,
                    currencySymbol: 'Bs',
                    format: _formatBsShort,
                    color: OrtizPalette.muted,
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: itemsInStore.isEmpty
                  ? const OrtizEmptyState(
                      icon: Icons.shopping_cart_outlined,
                      title: "No has añadido productos de esta tienda.",
                    )
                  : _buildItemsList(context, appState, itemsInStore, tripId, storeId),
            ),
          ],
        ),
      ),
      bottomNavigationBar: trip.isActive ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(OrtizSpace.lg),
          child: FilledButton.icon(
            onPressed: () {
              showResponsiveSheet(
                context: context,
                builder: (context) => AddMarketItemBottomSheet(
                  tripId: tripId,
                  initialStoreId: storeId,
                  forceStore: true,
                ),
              );
            },
            icon: const Icon(Icons.add, size: OrtizIconSize.md),
            label: const Text(
              "AGREGAR PRODUCTO",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                fontSize: OrtizFontSize.bodySm,
              ),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: OrtizSpace.lg),
            ),
          ),
        ),
      ) : null,
    );
  }

  Widget _buildItemsList(BuildContext context, AppState appState, List<MarketItem> items, String tripId, String storeId) {
    final pendingItems = items.where((i) => i.isPending).toList();
    final registeredItems = items.where((i) => !i.isPending).toList();

    var index = 0;
    final sections = <Widget>[];

    if (pendingItems.isNotEmpty) {
      sections.add(
        OrtizSection(
          title: "Pendientes",
          headerPadding: const EdgeInsets.symmetric(horizontal: OrtizListRow.inset),
          divided: true,
          children: [
            for (final item in pendingItems)
              ortizStaggered(
                context,
                index++,
                _buildPendingItemRow(context, appState, item, tripId, storeId),
              ),
          ],
        ),
      );
    }

    if (registeredItems.isNotEmpty) {
      sections.add(
        OrtizSection(
          title: "Registrados",
          headerPadding: const EdgeInsets.symmetric(horizontal: OrtizListRow.inset),
          divided: true,
          children: [
            for (final item in registeredItems)
              ortizStaggered(
                context,
                index++,
                _buildRegisteredItemRow(context, appState, item),
              ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        OrtizSpace.lg,
        OrtizSpace.md,
        OrtizSpace.lg,
        OrtizSpace.xxxl,
      ),
      children: sections,
    );
  }

  Widget _buildPendingItemRow(BuildContext context, AppState appState, MarketItem item, String tripId, String storeId) {
    return Row(
      children: [
        Checkbox(
          activeColor: AppColors.primary,
          value: false,
          onChanged: (val) {
            if (val == true) {
              // Open AddMarketItemBottomSheet in edit/register mode
              showResponsiveSheet(
                context: context,
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
          child: OrtizListRow(
            title: item.name,
            subtitle: item.category,
            trailing: IconButton(
              icon: const Icon(Icons.close, color: OrtizPalette.muted, size: OrtizIconSize.md),
              tooltip: 'Quitar producto',
              onPressed: () {
                _confirmDeleteItem(context, appState, item);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisteredItemRow(BuildContext context, AppState appState, MarketItem item) {
    final qtyStr = item.quantity.toString().endsWith('.0')
        ? item.quantity.toInt().toString()
        : item.quantity.toStringAsFixed(2);

    return OrtizListRow(
      leading: const Icon(Icons.fastfood_outlined),
      title: item.name,
      subtitle: "${item.category.toUpperCase()} · $qtyStr ${item.unit}",
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              OrtizAmount(
                value: item.priceUSD,
                currencySymbol: '\$',
                format: formatUSD,
              ),
              OrtizAmount(
                value: item.priceVES,
                currencySymbol: 'Bs',
                format: _formatBsShort,
                style: OrtizType.caption,
                color: OrtizPalette.muted,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: OrtizPalette.bad, size: OrtizIconSize.md),
            tooltip: 'Eliminar producto',
            onPressed: () {
              _confirmDeleteItem(context, appState, item);
            },
          ),
        ],
      ),
    );
  }

  void _showShoppingListBottomSheet(
    BuildContext context,
    AppState appState,
    String tripId,
    String storeId,
  ) {
    showResponsiveSheet(
      context: context,
      builder: (context) {
        final lists = appState.shoppingLists;

        return Container(
          decoration: const BoxDecoration(
            color: OrtizPalette.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(OrtizRadius.sheet)),
          ),
          padding: const EdgeInsets.all(OrtizSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Cargar Lista de Compras",
                style: TextStyle(
                  fontSize: OrtizFontSize.title,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: OrtizSpace.sm),
              const Text(
                "Selecciona una lista para cargar sus productos como pendientes en esta sesión.",
                style: TextStyle(color: OrtizPalette.muted, fontSize: OrtizFontSize.bodySm),
              ),
              const SizedBox(height: OrtizSpace.lg),
              if (lists.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(OrtizSpace.xxxl),
                    child: Text(
                      "No tienes ninguna lista de compras creada.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: OrtizPalette.muted),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: lists.length,
                  itemBuilder: (context, index) {
                    final list = lists[index];
                    return ListTile(
                      leading: const Icon(Icons.list_alt, color: AppColors.primary),
                      title: Text(list.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.chevron_right, color: OrtizPalette.muted),
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
    showResponsiveSheet(
      context: context,
      builder: (context) {
        return _ConfirmDeleteSheet(
          title: "¿Eliminar Establecimiento?",
          message: "Se eliminarán todos los productos registrados en este establecimiento para esta sesión.",
          onConfirm: () async {
            Navigator.pop(context); // Close bottom sheet
            for (var item in itemsInStore) {
              await appState.deleteMarketItem(item.id);
            }
            Navigator.pop(context); // Go back to trip screen
          },
        );
      },
    );
  }

  void _confirmDeleteItem(BuildContext context, AppState appState, MarketItem item) {
    showResponsiveSheet(
      context: context,
      builder: (context) {
        return _ConfirmDeleteSheet(
          title: "¿Eliminar Producto?",
          message: "¿Estás seguro que deseas remover ${item.name} de esta sesión?",
          onConfirm: () async {
            Navigator.pop(context); // Close bottom sheet
            await appState.deleteMarketItem(item.id);
          },
        );
      },
    );
  }
}

/// Hoja de confirmación de borrado (título en `bad`, Cancelar / Eliminar).
class _ConfirmDeleteSheet extends StatelessWidget {
  const _ConfirmDeleteSheet({
    required this.title,
    required this.message,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: OrtizPalette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(OrtizRadius.sheet)),
      ),
      padding: const EdgeInsets.all(OrtizSpace.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: OrtizFontSize.title,
              fontWeight: FontWeight.bold,
              color: OrtizPalette.bad,
            ),
          ),
          const SizedBox(height: OrtizSpace.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: OrtizPalette.muted),
          ),
          const SizedBox(height: OrtizSpace.xxl),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar", style: TextStyle(color: OrtizPalette.muted, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: OrtizSpace.lg),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OrtizPalette.bad,
                    foregroundColor: OrtizPalette.onAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: OrtizSpace.md),
                  ),
                  child: const Text("Eliminar", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
