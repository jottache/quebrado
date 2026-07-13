import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/claymorphic_card.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../models/market_item.dart';
import '../models/market_store.dart';
import '../models/market_trip.dart';
import '../models/market_product.dart';
import '../models/market_shopping_list.dart';
import '../models/market_shopping_list_item.dart';
import '../widgets/add_market_item_bottom_sheet.dart';
import '../widgets/add_market_product_bottom_sheet.dart';
import '../widgets/add_market_store_bottom_sheet.dart';
import 'market_trip_screen.dart';
import 'market_shopping_list_screen.dart';
import 'package:uuid/uuid.dart';

class MarketScreen extends StatefulWidget {
  @override
  _MarketScreenState createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> with SingleTickerProviderStateMixin {
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
    final spentThisMonth = appState.totalMarketSpentThisMonthUSD;
    final activeTrip = appState.marketTrips.where((t) => t.isActive).firstOrNull;

    return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            "Mercado",
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.only(bottom: 110.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey[500],
                    labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
        child: Icon(Icons.add, color: Colors.white),
      );
    } else if (_tabController.index == 1) {
      return FloatingActionButton(
        heroTag: "fab_store",
        onPressed: () {
          _showAddStoreDialog(context);
        },
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: Icon(Icons.add, color: Colors.white),
      );
    } else if (_tabController.index == 2) {
      return FloatingActionButton(
        heroTag: "fab_catalog",
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => AddMarketProductBottomSheet(),
          );
        },
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: Icon(Icons.add, color: Colors.white),
      );
    } else if (_tabController.index == 3) {
      return FloatingActionButton(
        heroTag: "fab_shopping_list",
        onPressed: () {
          _showCreateShoppingListDialog(context, appState);
        },
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: Icon(Icons.add, color: Colors.white),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.cardText,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.cardSubtitleText,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
        final items = appState.marketItems.where((i) => i.tripId == trip.id);
        monthTotalUSD += items.fold(0.0, (sum, i) => sum + i.priceUSD);
        monthTotalVES += items.fold(0.0, (sum, i) => sum + i.priceVES);
      }
      
      listItems.add(_HeaderItem(monthYear, monthTotalUSD, monthTotalVES));
      for (var trip in trips) {
        listItems.add(_CardItem(trip));
      }
    });

    return ListView.builder(
      padding: EdgeInsets.only(bottom: 100, top: 8),
      itemCount: listItems.length,
      itemBuilder: (context, index) {
        final item = listItems[index];
        if (item is _HeaderItem) {
          final matchingTrips = sortedTrips.where((t) {
            final monthName = _getMonthName(t.date.month);
            return "$monthName ${t.date.year}" == item.title;
          }).toList();

          return Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
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
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => _MonthDetailsBottomSheet(
                            monthYear: item.title,
                            trips: matchingTrips,
                            appState: appState,
                          ),
                        );
                      },
                      child: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Text(
                  "\$${item.totalUSD.toStringAsFixed(2)} • Bs ${item.totalVES.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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
          final tripTotalUSD = itemsInTrip.fold(0.0, (sum, i) => sum + i.priceUSD);
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MarketTripScreen(tripId: trip.id),
                  ),
                );
              },
              child: ClaymorphicCard(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                  fontSize: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                              if (trip.isActive) ...[
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "ACTIVA",
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            "${trip.date.day}/${trip.date.month}/${trip.date.year}",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "${visitedStores.length} lugares visitados",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
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
                            fontSize: 22,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return SizedBox.shrink();
      },
    );
  }

  Widget _buildStoresTab(AppState appState) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Tus Establecimientos",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey[700],
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
                  padding: EdgeInsets.only(bottom: 100, top: 16),
                  itemCount: appState.marketStores.length,
                  itemBuilder: (context, index) {
                    final store = appState.marketStores[index];
                    final itemsInStore = appState.marketItems.where((i) => i.storeId == store.id).toList();
                    final totalUSD = itemsInStore.fold(0.0, (sum, i) => sum + i.priceUSD);
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: ClaymorphicCard(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                      fontSize: 16,
                                      color: AppColors.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    "${itemsInStore.length} productos registrados",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
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
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.edit_outlined, color: Colors.grey[700], size: 18),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      if (itemsInStore.isNotEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("No puedes eliminar un establecimiento que tiene productos registrados en el historial."),
                                            backgroundColor: Colors.red[400],
                                          ),
                                        );
                                      } else {
                                        _confirmDeleteStore(context, appState, store);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red[50],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.delete_outline, color: Colors.red[400], size: 18),
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
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Catálogo Global",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey[700],
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
                  padding: EdgeInsets.only(bottom: 100),
                  itemCount: appState.marketProducts.length,
                  itemBuilder: (context, index) {
                    final product = appState.marketProducts[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: ClaymorphicCard(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                      fontSize: 16,
                                      color: AppColors.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    product.category,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
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
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) => AddMarketProductBottomSheet(productToEdit: product),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.edit_outlined, color: Colors.grey[700], size: 18),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      appState.deleteMarketProduct(product.id);
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red[50],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.delete_outline, color: Colors.red[400], size: 18),
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

  Widget _buildShoppingListsTab(AppState appState) {
    if (appState.shoppingLists.isEmpty) {
      return _buildEmptyState(
        icon: Icons.list_alt_rounded,
        title: "No tienes listas de compras",
        subtitle: "Crea listas de compras para planificar lo que necesitas antes de salir de casa.",
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: appState.shoppingLists.length,
      itemBuilder: (context, index) {
        final list = appState.shoppingLists[index];
        final itemsInList = appState.shoppingListItems.where((i) => i.listId == list.id).toList();
        final checkedItemsCount = itemsInList.where((i) => i.isChecked).length;
        
        final dateStr = "${list.date.day}/${list.date.month}/${list.date.year}";

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MarketShoppingListScreen(listId: list.id),
                ),
              );
            },
            child: ClaymorphicCard(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.playlist_add_check, color: AppColors.primary, size: 22),
                  ),
                  SizedBox(width: 12),
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
                                fontSize: 16,
                                color: AppColors.primary,
                              ),
                            ),
                            if (list.isActive) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "ACTIVA",
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          "$dateStr • $checkedItemsCount/${itemsInList.length} completados",
                          style: TextStyle(
                            color: AppColors.cardSubtitleText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red[300], size: 22),
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
                "¿Eliminar Lista?",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 12),
              Text(
                "¿Estás seguro de que deseas eliminar la lista '${list.title}'? Esta acción no se puede deshacer.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text("Cancelar"),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await appState.deleteMarketShoppingList(list.id);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                  "Nueva Lista de Compras",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: "Nombre de la lista (ej: Compras del mes)",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  autofocus: true,
                ),
                SizedBox(height: 20),
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
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
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
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[500],
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
          child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () {
            appState.deleteMarketStore(store.id);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Establecimiento eliminado")),
            );
          },
          child: Text("Eliminar", style: TextStyle(color: Colors.red)),
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
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "Detalles de Compras - $monthYear",
              style: TextStyle(
                fontSize: 18,
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
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final store = appState.marketStores.firstWhere(
                        (s) => s.id == item.storeId,
                        orElse: () => MarketStore(id: '', name: 'Lugar Desconocido'),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ClaymorphicCard(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      store.name,
                                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
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
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    "Bs ${item.priceVES.toStringAsFixed(2)}",
                                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
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
          SizedBox(height: 20),
        ],
      ),
    );
  }
}
