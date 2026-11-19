import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../models/currency_type.dart';
import '../models/market_item.dart';
import '../models/market_store.dart';
import '../models/market_trip.dart';
import '../models/market_product.dart';
import '../models/market_shopping_list.dart';
import '../models/market_shopping_list_item.dart';
import '../widgets/add_market_item_bottom_sheet.dart';
import '../widgets/add_market_product_bottom_sheet.dart';
import '../widgets/add_market_store_bottom_sheet.dart';
import '../widgets/product_details_bottom_sheet.dart';
import 'market_trip_screen.dart';
import 'market_shopping_list_screen.dart';
import 'package:uuid/uuid.dart';
import '../../widgets/responsive_breakpoints.dart';
import '../../widgets/responsive_sheet_helper.dart';
import '../dialogs/book_selector_dialog.dart';
import 'settings_screen.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

/// Espacio bajo las listas para que el último elemento no quede bajo el FAB.
const double _fabClearance = OrtizSize.minTouch * 2 + OrtizSpace.lg;

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (context) => const _MarketScreenContent(),
      ),
    );
  }
}

class _MarketScreenContent extends StatefulWidget {
  const _MarketScreenContent({super.key});

  @override
  _MarketScreenContentState createState() => _MarketScreenContentState();
}

class _MarketScreenContentState extends State<_MarketScreenContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);
    final spentThisMonth = appState.totalMarketSpentThisMonthUSD;
    final activeTrip = appState.marketTrips.where((t) => t.isActive).firstOrNull;

    return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: isDesktop
              ? Padding(
                  padding: const EdgeInsets.only(left: OrtizSpace.md),
                  child: Center(
                    child: ActionChip(
                      avatar: const Icon(Icons.auto_stories_rounded, size: OrtizIconSize.sm),
                      label: Text(
                        appState.activeProfileName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.bodySm),
                      ),
                      onPressed: () {
                        showResponsiveSheet(
                          context: context,
                          builder: (context) => const BookSelectorBottomSheet(),
                        );
                      },
                    ),
                  ),
                )
              : null,
          leadingWidth: isDesktop ? 180 : null,
          title: Text(
            "Mercado",
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (isDesktop)
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: "Ajustes",
                onPressed: () {
                  showResponsiveSheet(
                    context: context,
                    builder: (context) => const SettingsScreen(),
                  );
                },
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.only(bottom: _fabClearance),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: OrtizPalette.surfaceHigh,
                    borderRadius: BorderRadius.circular(OrtizRadius.field),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(OrtizRadius.chip),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: OrtizPalette.onAccent,
                    unselectedLabelColor: OrtizPalette.muted,
                    labelStyle: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w800),
                    unselectedLabelStyle: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w600),
                    tabs: [
                      Tab(text: "Sesiones"),
                      Tab(text: "Lugares"),
                      Tab(text: "Catálogo"),
                      Tab(text: "Listas"),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    _buildTripsTab(appState, activeTrip),
                    _buildStoresTab(appState),
                    _buildProductsTab(appState),
                    _buildShoppingListsTab(appState),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _buildFAB(appState),
        floatingActionButtonLocation: const _OffsetFabLocation(
          FloatingActionButtonLocation.endFloat,
          offsetY: -110.0,
        ),
      );
  }

  Widget? _buildFAB(AppState appState) {
    if (_tabController.index == 0) {
      final activeTrip = appState.marketTrips.where((t) => t.isActive).firstOrNull;
      if (activeTrip != null) return null;
      return FloatingActionButton(
        heroTag: "fab_session",
        onPressed: () {
          // Iniciar Nueva Sesión
          _startNewTrip(context);
        },
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: Icon(Icons.add, color: OrtizPalette.onAccent),
      );
    } else if (_tabController.index == 1) {
      return FloatingActionButton(
        heroTag: "fab_store",
        onPressed: () {
          _showAddStoreDialog(context);
        },
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: Icon(Icons.add, color: OrtizPalette.onAccent),
      );
    } else if (_tabController.index == 2) {
      return FloatingActionButton(
        heroTag: "fab_catalog",
        onPressed: () {
          showResponsiveSheet(
            context: context,
            builder: (context) => const AddMarketProductBottomSheet(),
          );
        },
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: Icon(Icons.add, color: OrtizPalette.onAccent),
      );
    } else if (_tabController.index == 3) {
      return FloatingActionButton(
        heroTag: "fab_shopping_list",
        onPressed: () {
          _showCreateShoppingListDialog(context, appState);
        },
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: Icon(Icons.add, color: OrtizPalette.onAccent),
      );
    }
    return null;
  }

  void _startNewTrip(BuildContext context) async {
    final appState = Provider.of<AppState>(context, listen: false);
    
    // Check if there is an active trip already
    final activeTrip = appState.marketTrips.where((t) => t.isActive).firstOrNull;
    if (activeTrip != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ya tienes una sesión activa.')),
      );
      return;
    }

    final newTrip = MarketTrip(
      id: Uuid().v4(),
      title: 'Compra del ${DateTime.now().day}/${DateTime.now().month}',
      date: DateTime.now(),
      isActive: true,
    );
    await appState.addMarketTrip(newTrip);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarketTripScreen(tripId: newTrip.id),
      ),
    );
  }

  void _showAddStoreDialog(BuildContext context) {
    showResponsiveSheet(
      context: context,
      builder: (context) => AddMarketStoreBottomSheet(
        onStoreAdded: (_) {},
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return months[month - 1];
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return OrtizEmptyState(icon: icon, title: title, message: subtitle);
  }

  Map<String, double> _getTripTotals(AppState appState, MarketTrip trip) {
    final itemsInTrip = appState.marketItems.where((i) => i.tripId == trip.id).toList();
    double tripTotalUSD = 0.0;
    double tripTotalVES = 0.0;

    if (itemsInTrip.isNotEmpty) {
      tripTotalUSD = itemsInTrip.fold(0.0, (sum, i) => sum + i.priceUSD);
      tripTotalVES = itemsInTrip.fold(0.0, (sum, i) => sum + i.priceVES);
    } else if (trip.transactionId != null) {
      final txMatches = appState.transactions.where((t) => t.id == trip.transactionId);
      if (txMatches.isNotEmpty) {
        final tx = txMatches.first;
        if (tx.currency == CurrencyType.usd) {
          tripTotalUSD = tx.amount;
          tripTotalVES = tx.amount * (tx.exchangeRate > 0 ? tx.exchangeRate : appState.bcvRate);
        } else {
          tripTotalVES = tx.amount;
          final rate = tx.exchangeRate > 0 ? tx.exchangeRate : appState.bcvRate;
          tripTotalUSD = rate > 0 ? tx.amount / rate : 0.0;
        }
      }
    }
    return {'usd': tripTotalUSD, 'ves': tripTotalVES};
  }

  Widget _buildTripsTab(AppState appState, MarketTrip? activeTrip) {
    if (appState.marketTrips.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_rounded,
        title: "No hay sesiones de compra",
        subtitle: "Inicia una nueva sesión presionando el botón '+' para empezar a registrar tus compras en tiempo real.",
      );
    }

    final List<_TripsListItem> listItems = [];
    
    final sortedTrips = List<MarketTrip>.from(appState.marketTrips)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Grouping
    final Map<String, List<MarketTrip>> grouped = {};
    for (var trip in sortedTrips) {
      final monthName = _getMonthName(trip.date.month);
      final key = "$monthName ${trip.date.year}";
      grouped.putIfAbsent(key, () => []).add(trip);
    }

    grouped.forEach((monthYear, trips) {
      double monthTotalUSD = 0.0;
      double monthTotalVES = 0.0;
      for (var trip in trips) {
        final totals = _getTripTotals(appState, trip);
        monthTotalUSD += totals['usd']!;
        monthTotalVES += totals['ves']!;
      }
      
      listItems.add(_HeaderItem(monthYear, monthTotalUSD, monthTotalVES));
      for (var trip in trips) {
        listItems.add(_CardItem(trip));
      }
    });

    return ListView.builder(
      padding: EdgeInsets.only(bottom: _fabClearance,top: OrtizSpace.sm),
      itemCount: listItems.length,
      itemBuilder: (context, index) {
        final item = listItems[index];
        if (item is _HeaderItem) {
          final matchingTrips = sortedTrips.where((t) {
            final monthName = _getMonthName(t.date.month);
            return "$monthName ${t.date.year}" == item.title;
          }).toList();

          return Padding(
            padding: const EdgeInsets.only(left: OrtizSpace.lg, right: OrtizSpace.lg, top: OrtizSpace.lg, bottom: OrtizSpace.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(OrtizRadius.chip),
                      ),
                    ),
                    SizedBox(width: OrtizSpace.sm),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: OrtizFontSize.body,
                        color: OrtizPalette.muted,
                      ),
                    ),
                    SizedBox(width: OrtizSpace.xs),
                    GestureDetector(
                      onTap: () {
                        showResponsiveSheet(
                          context: context,
                          builder: (context) => _MonthDetailsBottomSheet(
                            monthYear: item.title,
                            trips: matchingTrips,
                            appState: appState,
                          ),
                        );
                      },
                      child: Icon(
                        Icons.info_outline,
                        size: OrtizIconSize.sm,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Text(
                  "\$${item.totalUSD.toStringAsFixed(2)} • Bs ${item.totalVES.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: OrtizFontSize.bodySm,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          );
        } else if (item is _CardItem) {
          final trip = item.trip;
          final itemsInTrip = appState.marketItems.where((i) => i.tripId == trip.id).toList();
          final visitedStores = itemsInTrip.map((e) => e.storeId).toSet();
          final totals = _getTripTotals(appState, trip);
          final tripTotalUSD = totals['usd']!;
          final tripTotalVES = totals['ves']!;

          return ortizStaggered(context, index, Padding(
            padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.xs),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MarketTripScreen(tripId: trip.id),
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                trip.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: OrtizFontSize.titleSm,
                                  color: AppColors.primary,
                                ),
                              ),
                              if (trip.isActive) ...[
                                SizedBox(width: OrtizSpace.sm),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: OrtizSpace.xs, vertical: OrtizSpace.xxs),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(OrtizRadius.chip),
                                  ),
                                  child: Text(
                                    "ACTIVA",
                                    style: TextStyle(
                                      fontSize: OrtizFontSize.micro,
                                      fontWeight: FontWeight.bold,
                                      color: OrtizPalette.onAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: OrtizSpace.xs),
                          Text(
                            "${trip.date.day}/${trip.date.month}/${trip.date.year}",
                            style: TextStyle(
                              color: OrtizPalette.muted,
                              fontSize: OrtizFontSize.bodySm,
                            ),
                          ),
                          SizedBox(height: OrtizSpace.xs),
                          Text(
                            visitedStores.isNotEmpty
                                ? "${visitedStores.length} lugares visitados"
                                : (trip.transactionId != null ? "Finalizada (Ver Transacción)" : "0 lugares visitados"),
                            style: TextStyle(
                              color: OrtizPalette.muted,
                              fontSize: OrtizFontSize.bodySm,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "\$${tripTotalUSD.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: OrtizFontSize.display,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ));
        }
        return SizedBox.shrink();
      },
    );
  }

  Widget _buildStoresTab(AppState appState) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Tus Establecimientos",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: OrtizFontSize.body,
                color: OrtizPalette.muted,
              ),
            ),
          ),
        ),
        Expanded(
          child: appState.marketStores.isEmpty
              ? _buildEmptyState(
                  icon: Icons.storefront_rounded,
                  title: "Sin establecimientos",
                  subtitle: "Registra los lugares donde sueles comprar (supermercados, farmacias, tiendas) para organizar tus compras.",
                )
              : ListView.builder(
                  padding: EdgeInsets.only(bottom: _fabClearance,top: OrtizSpace.lg),
                  itemCount: appState.marketStores.length,
                  itemBuilder: (context, index) {
                    final store = appState.marketStores[index];
                    final itemsInStore = appState.marketItems.where((i) => i.storeId == store.id).toList();
                    final totalUSD = itemsInStore.fold(0.0, (sum, i) => sum + i.priceUSD);
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.xs),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.md),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    store.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: OrtizFontSize.titleSm,
                                      color: AppColors.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: OrtizSpace.xxs),
                                  Text(
                                    "${itemsInStore.length} productos registrados",
                                    style: TextStyle(
                                      color: OrtizPalette.muted,
                                      fontSize: OrtizFontSize.bodySm,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      _editStore(context, appState, store);
                                    },
                                    borderRadius: BorderRadius.circular(OrtizRadius.dialog),
                                    child: Container(
                                      padding: EdgeInsets.all(OrtizSpace.sm),
                                      decoration: BoxDecoration(
                                        color: OrtizPalette.surfaceHigh,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.edit_outlined, color: OrtizPalette.muted, size: OrtizIconSize.sm),
                                    ),
                                  ),
                                ),
                                SizedBox(width: OrtizSpace.md),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      if (itemsInStore.isNotEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("No puedes eliminar un establecimiento que tiene productos registrados en el historial."),
                                            backgroundColor: OrtizPalette.bad,
                                          ),
                                        );
                                      } else {
                                        _confirmDeleteStore(context, appState, store);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(OrtizRadius.dialog),
                                    child: Container(
                                      padding: EdgeInsets.all(OrtizSpace.sm),
                                      decoration: BoxDecoration(
                                        color: OrtizPalette.badTint,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.delete_outline, color: OrtizPalette.bad, size: OrtizIconSize.sm),
                                    ),
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
    );
  }

  Widget _buildProductsTab(AppState appState) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Catálogo Global",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: OrtizFontSize.body,
                color: OrtizPalette.muted,
              ),
            ),
          ),
        ),
        Expanded(
          child: appState.marketProducts.isEmpty
              ? _buildEmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: "Catálogo vacío",
                  subtitle: "Agrega productos de uso común a tu catálogo para que registrarlos sea tan fácil como un toque.",
                )
              : ListView.builder(
                  padding: EdgeInsets.only(bottom: _fabClearance),
                  itemCount: appState.marketProducts.length,
                  itemBuilder: (context, index) {
                    final product = appState.marketProducts[index];
                    return ortizStaggered(context, index, Padding(
                      padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.xs),
                      child: GestureDetector(
                        onTap: () {
                          showResponsiveSheet(
                            context: context,
                            builder: (context) => ProductDetailsBottomSheet(product: product),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.md),
                          child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: OrtizFontSize.titleSm,
                                      color: AppColors.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: OrtizSpace.xxs),
                                  Text(
                                    product.category,
                                    style: TextStyle(
                                      color: OrtizPalette.muted,
                                      fontSize: OrtizFontSize.bodySm,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      showResponsiveSheet(
                                        context: context,
                                        builder: (context) => AddMarketProductBottomSheet(productToEdit: product),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(OrtizRadius.dialog),
                                    child: Container(
                                      padding: EdgeInsets.all(OrtizSpace.sm),
                                      decoration: BoxDecoration(
                                        color: OrtizPalette.surfaceHigh,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.edit_outlined, color: OrtizPalette.muted, size: OrtizIconSize.sm),
                                    ),
                                  ),
                                ),
                                SizedBox(width: OrtizSpace.md),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      appState.deleteMarketProduct(product.id);
                                    },
                                    borderRadius: BorderRadius.circular(OrtizRadius.dialog),
                                    child: Container(
                                      padding: EdgeInsets.all(OrtizSpace.sm),
                                      decoration: BoxDecoration(
                                        color: OrtizPalette.badTint,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.delete_outline, color: OrtizPalette.bad, size: OrtizIconSize.sm),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ));
                },
                ),
        ),
      ],
    );
  }

  Widget _buildShoppingListsTab(AppState appState) {
    if (appState.shoppingLists.isEmpty) {
      return _buildEmptyState(
        icon: Icons.list_alt_rounded,
        title: "No tienes listas de compras",
        subtitle: "Crea listas de compras para planificar lo que necesitas antes de salir de casa.",
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
      itemCount: appState.shoppingLists.length,
      itemBuilder: (context, index) {
        final list = appState.shoppingLists[index];
        final itemsInList = appState.shoppingListItems.where((i) => i.listId == list.id).toList();
        final checkedItemsCount = itemsInList.where((i) => i.isChecked).length;
        
        final dateStr = "${list.date.day}/${list.date.month}/${list.date.year}";

        return Padding(
          padding: const EdgeInsets.only(bottom: OrtizSpace.sm),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MarketShoppingListScreen(listId: list.id),
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.md),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.playlist_add_check, color: AppColors.primary, size: OrtizIconSize.md),
                  ),
                  SizedBox(width: OrtizSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              list.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: OrtizFontSize.titleSm,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: OrtizSpace.xs),
                        Text(
                          "$dateStr • $checkedItemsCount/${itemsInList.length} completados",
                          style: TextStyle(
                            color: AppColors.cardSubtitleText,
                            fontSize: OrtizFontSize.bodySm,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: OrtizPalette.bad, size: OrtizIconSize.md),
                    onPressed: () {
                      _confirmDeleteShoppingList(context, appState, list);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteShoppingList(BuildContext context, AppState appState, MarketShoppingList list) {
    showResponsiveSheet(
      context: context,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: OrtizPalette.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(OrtizRadius.sheet)),
          ),
          padding: const EdgeInsets.all(OrtizSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "¿Eliminar Lista?",
                style: TextStyle(
                  fontSize: OrtizFontSize.title,
                  fontWeight: FontWeight.bold,
                  color: OrtizPalette.bad,
                ),
              ),
              SizedBox(height: OrtizSpace.md),
              Text(
                "¿Estás seguro de que deseas eliminar la lista '${list.title}'? Esta acción no se puede deshacer.",
                textAlign: TextAlign.center,
                style: TextStyle(color: OrtizPalette.muted),
              ),
              SizedBox(height: OrtizSpace.xxl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(OrtizRadius.field),
                        ),
                      ),
                      child: Text("Cancelar"),
                    ),
                  ),
                  SizedBox(width: OrtizSpace.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await appState.deleteMarketShoppingList(list.id);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OrtizPalette.bad,
                        foregroundColor: OrtizPalette.onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(OrtizRadius.field),
                        ),
                      ),
                      child: Text("Eliminar"),
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

  void _showCreateShoppingListDialog(BuildContext context, AppState appState) {
    final controller = TextEditingController();
    showResponsiveSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: OrtizPalette.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(OrtizRadius.sheet)),
            ),
            padding: const EdgeInsets.all(OrtizSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Nueva Lista de Compras",
                  style: TextStyle(
                    fontSize: OrtizFontSize.title,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: OrtizSpace.lg),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: "Nombre de la lista (ej: Compras del mes)",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.field),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  autofocus: true,
                ),
                SizedBox(height: OrtizSpace.xl),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = controller.text.trim();
                      if (title.isNotEmpty) {
                        final newList = MarketShoppingList(
                          id: Uuid().v4(),
                          title: title,
                          date: DateTime.now(),
                          isActive: true,
                        );
                        await appState.addMarketShoppingList(newList);
                        Navigator.pop(context);
                        // Navigate to detail screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MarketShoppingListScreen(listId: newList.id),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: OrtizPalette.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OrtizRadius.field),
                      ),
                    ),
                    child: Text("Crear Lista"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void _editStore(BuildContext context, AppState appState, MarketStore store) {
  final controller = TextEditingController(text: store.name);
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Editar Establecimiento"),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: "Nombre del establecimiento",
          filled: true,
          fillColor: OrtizPalette.surfaceHigh,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(OrtizRadius.chip), borderSide: BorderSide.none),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancelar", style: TextStyle(color: OrtizPalette.muted)),
        ),
        TextButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              store.name = controller.text.trim();
              appState.updateMarketStore(store);
              Navigator.pop(context);
            }
          },
          child: Text("Guardar", style: TextStyle(color: AppColors.primary)),
        ),
      ],
    ),
  );
}

class _TabSegment extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabSegment({
    Key? key,
    required this.title,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(OrtizRadius.chip),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: OrtizFontSize.bodySm,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? OrtizPalette.onAccent : OrtizPalette.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _confirmDeleteStore(BuildContext context, AppState appState, store) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Eliminar Establecimiento"),
      content: Text(
        "¿Estás seguro de eliminar '${store.name}'?\n\n"
        "Se eliminarán todos los productos asociados a este establecimiento en el historial de compras."
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancelar", style: TextStyle(color: OrtizPalette.muted)),
        ),
        TextButton(
          onPressed: () {
            appState.deleteMarketStore(store.id);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Establecimiento eliminado")),
            );
          },
          child: Text("Eliminar", style: TextStyle(color: OrtizPalette.bad)),
        ),
      ],
    ),
  );
}

class _OffsetFabLocation extends FloatingActionButtonLocation {
  final FloatingActionButtonLocation original;
  final double offsetX;
  final double offsetY;

  const _OffsetFabLocation(this.original, {this.offsetX = 0, this.offsetY = 0});

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final Offset originalOffset = original.getOffset(scaffoldGeometry);
    return Offset(originalOffset.dx + offsetX, originalOffset.dy + offsetY);
  }
}

abstract class _TripsListItem {}

class _HeaderItem extends _TripsListItem {
  final String title;
  final double totalUSD;
  final double totalVES;
  _HeaderItem(this.title, this.totalUSD, this.totalVES);
}

class _CardItem extends _TripsListItem {
  final MarketTrip trip;
  _CardItem(this.trip);
}

class _MonthDetailsBottomSheet extends StatelessWidget {
  final String monthYear;
  final List<MarketTrip> trips;
  final AppState appState;

  const _MonthDetailsBottomSheet({
    required this.monthYear,
    required this.trips,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final tripIds = trips.map((t) => t.id).toSet();
    final items = appState.marketItems.where((i) => tripIds.contains(i.tripId)).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: OrtizPalette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(OrtizRadius.sheet)),
      ),
      child: Column(
        children: [
          SizedBox(height: OrtizSpace.lg),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: OrtizPalette.faint,
              borderRadius: BorderRadius.circular(OrtizRadius.chip),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(OrtizSpace.xl),
            child: Text(
              "Detalles de Compras - $monthYear",
              style: TextStyle(
                fontSize: OrtizFontSize.title,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      "No hay productos registrados este mes.",
                      style: TextStyle(color: OrtizPalette.muted),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: OrtizSpace.lg),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final store = appState.marketStores.firstWhere(
                        (s) => s.id == item.storeId,
                        orElse: () => MarketStore(id: '', name: 'Lugar Desconocido'),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: OrtizSpace.sm),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.md),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: OrtizFontSize.body),
                                    ),
                                    SizedBox(height: OrtizSpace.xxs),
                                    Text(
                                      store.name,
                                      style: TextStyle(color: OrtizPalette.muted, fontSize: OrtizFontSize.caption),
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
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: OrtizFontSize.body,
                                    ),
                                  ),
                                  Text(
                                    "Bs ${item.priceVES.toStringAsFixed(2)}",
                                    style: TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.muted),
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
          SizedBox(height: OrtizSpace.xl),
        ],
      ),
    );
  }
}
