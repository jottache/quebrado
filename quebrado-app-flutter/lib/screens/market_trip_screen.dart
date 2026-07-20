import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../viewmodels/app_state.dart';
import '../models/market_item.dart';
import '../models/market_trip.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import '../models/transaction_category.dart';
import '../models/currency_type.dart';
import '../widgets/helpers.dart';
import '../widgets/add_market_item_bottom_sheet.dart';
import '../widgets/claymorphic_background.dart';
import '../widgets/claymorphic_card.dart';
import '../services/biometric_service.dart';
import '../widgets/add_market_store_bottom_sheet.dart';
import 'market_trip_store_screen.dart';
import 'package:uuid/uuid.dart';

class MarketTripScreen extends StatelessWidget {
  final String tripId;

  const MarketTripScreen({Key? key, required this.tripId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final tripMatches = appState.marketTrips.where((t) => t.id == tripId);
    if (tripMatches.isEmpty) {
      return const Scaffold(backgroundColor: AppColors.background);
    }
    final trip = tripMatches.first;
    final itemsInTrip = appState.marketItems.where((i) => i.tripId == tripId).toList();
    
    // Group by store
    final Map<String, List<MarketItem>> itemsByStore = {};
    for (var item in itemsInTrip) {
      if (!itemsByStore.containsKey(item.storeId)) {
        itemsByStore[item.storeId] = [];
      }
      itemsByStore[item.storeId]!.add(item);
    }
    
    final totalUSD = itemsInTrip.fold(0.0, (sum, i) => sum + i.priceUSD);
    final totalVES = itemsInTrip.fold(0.0, (sum, i) => sum + i.priceVES);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primary),
        title: Text(
          trip.title,
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red[300]),
            onPressed: () {
              _confirmDeleteTrip(context, appState, trip);
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
                          "TOTAL SESIÓN",
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Tus Compras",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),
            Expanded(
              child: itemsByStore.isEmpty
                  ? Center(
                      child: Text(
                        "No has registrado compras en ningún establecimiento.",
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(bottom: 100),
                      itemCount: itemsByStore.keys.length,
                      itemBuilder: (context, index) {
                        final storeId = itemsByStore.keys.elementAt(index);
                        final store = appState.marketStores.firstWhere(
                          (s) => s.id == storeId,
                          orElse: () => appState.marketStores.first,
                        );
                        final storeItems = itemsByStore[storeId]!;
                        final storeTotalUSD = storeItems.fold(0.0, (sum, i) => sum + i.priceUSD);
                        final storeTotalVES = storeItems.fold(0.0, (sum, i) => sum + i.priceVES);
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MarketTripStoreScreen(
                                    tripId: tripId,
                                    storeId: storeId,
                                  ),
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
                                    child: Icon(Icons.storefront, color: AppColors.primary, size: 20),
                                  ),
                                  SizedBox(width: 12),
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
                                        SizedBox(height: 4),
                                        Text(
                                          "${storeItems.length} productos",
                                          style: TextStyle(
                                            color: AppColors.cardSubtitleText,
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
                                        "\$${storeTotalUSD.toStringAsFixed(2)}",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      Text(
                                        "Bs ${storeTotalVES.toStringAsFixed(2)}",
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
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: trip.isActive ? [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showStoreSelector(context, appState, tripId);
                  },
                  icon: Icon(Icons.storefront),
                  label: Text(
                    "ENTRAR A ESTABLECIMIENTO",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      fontSize: 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    _confirmFinishTrip(context, appState, trip);
                  },
                  icon: Icon(Icons.check_circle, color: Colors.white),
                  label: Text(
                    "FINALIZAR SESIÓN",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 12),
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
            ] : [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    trip.isActive = true;
                    await appState.updateMarketTrip(trip);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Sesión reabierta")),
                    );
                  },
                  icon: Icon(Icons.refresh, color: Colors.white),
                  label: Text(
                    "REABRIR SESIÓN",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 12),
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
            ],
          ),
        ),
      ),
    );
  }

  void _confirmFinishTrip(BuildContext context, AppState appState, MarketTrip trip) {
    final itemsInTrip = appState.marketItems.where((i) => i.tripId == trip.id).toList();
    final totalVES = itemsInTrip.fold(0.0, (sum, i) => sum + i.priceVES);
    final totalUSD = itemsInTrip.fold(0.0, (sum, i) => sum + i.priceUSD);
    
    if (totalVES <= 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Sesión Vacía"),
          content: Text("No puedes finalizar una sesión de compras con un total de 0. Registra productos antes de finalizar."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FinishMarketTripBottomSheet(
        appState: appState,
        trip: trip,
        totalVES: totalVES,
        totalUSD: totalUSD,
      ),
    );
  }

  void _editTrip(BuildContext context, AppState appState, MarketTrip trip) {
    final controller = TextEditingController(text: trip.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Editar Sesión"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Título de la sesión",
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
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                trip.title = controller.text.trim();
                await appState.updateMarketTrip(trip);
                Navigator.pop(context);
              }
            },
            child: Text("Guardar", style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showStoreSelector(BuildContext context, AppState appState, String tripId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
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
                "Selecciona un establecimiento",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: appState.marketStores.length,
                itemBuilder: (context, index) {
                  final store = appState.marketStores[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ClaymorphicCard(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Icon(Icons.storefront, color: AppColors.primary),
                        ),
                        title: Text(
                          store.name,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          Navigator.pop(context); // close bottom sheet
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MarketTripStoreScreen(
                                tripId: tripId,
                                storeId: store.id,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => AddMarketStoreBottomSheet(
                          onStoreAdded: (newStoreId) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MarketTripStoreScreen(
                                  tripId: tripId,
                                  storeId: newStoreId,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    icon: Icon(Icons.add),
                    label: Text(
                      "NUEVO ESTABLECIMIENTO",
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
              ),
            )
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTrip(BuildContext context, AppState appState, MarketTrip trip) {
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
                "¿Eliminar Sesión?",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 12),
              Text(
                "Se eliminarán todos los productos registrados en esta sesión. Esta acción no se puede deshacer.",
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
                        // Delete all items in the trip
                        final itemsInTrip = appState.marketItems.where((i) => i.tripId == trip.id).toList();
                        for (var item in itemsInTrip) {
                          await appState.deleteMarketItem(item.id);
                        }
                        // Delete the trip itself
                        await appState.deleteMarketTrip(trip.id);
                        Navigator.pop(context); // Go back to market screen
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

class FinishMarketTripBottomSheet extends StatefulWidget {
  final AppState appState;
  final MarketTrip trip;
  final double totalVES;
  final double totalUSD;

  const FinishMarketTripBottomSheet({
    Key? key,
    required this.appState,
    required this.trip,
    required this.totalVES,
    required this.totalUSD,
  }) : super(key: key);

  @override
  _FinishMarketTripBottomSheetState createState() => _FinishMarketTripBottomSheetState();
}

class _FinishMarketTripBottomSheetState extends State<FinishMarketTripBottomSheet> {
  Account? _selectedAccount;
  TransactionCategory? _selectedCategory;
  late TextEditingController _descriptionController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    
    // Set default account: first VES account, else first account
    final vesAccounts = widget.appState.accounts.where((a) => a.currency == CurrencyType.bsBCV);
    if (vesAccounts.isNotEmpty) {
      _selectedAccount = vesAccounts.first;
    } else if (widget.appState.accounts.isNotEmpty) {
      _selectedAccount = widget.appState.accounts.first;
    }

    // Set default category: named "comida", else first category
    final comidaCategories = widget.appState.categories.where((c) => c.name.toLowerCase() == 'comida');
    if (comidaCategories.isNotEmpty) {
      _selectedCategory = comidaCategories.first;
    } else if (widget.appState.categories.isNotEmpty) {
      _selectedCategory = widget.appState.categories.first;
    }

    _descriptionController = TextEditingController(text: "Compra de Mercado: ${widget.trip.title}");

    // Prefill if re-finalizing
    if (widget.trip.transactionId != null) {
      final matches = widget.appState.transactions.where((t) => t.id == widget.trip.transactionId);
      if (matches.isNotEmpty) {
        final oldTx = matches.first;
        final accMatches = widget.appState.accounts.where((a) => a.id == oldTx.accountId);
        if (accMatches.isNotEmpty) _selectedAccount = accMatches.first;
        
        final catMatches = widget.appState.categories.where((c) => c.id == oldTx.categoryId);
        if (catMatches.isNotEmpty) _selectedCategory = catMatches.first;

        _descriptionController.text = oldTx.note;
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _finishSession() async {
    if (_selectedAccount == null || _selectedCategory == null) return;

    setState(() {
      _loading = true;
    });

    try {
      if (widget.appState.useBiometrics) {
        bool authenticated = await BiometricService.authenticate();
        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Autenticación fallida', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
            );
          }
          setState(() {
            _loading = false;
          });
          return;
        }
      }

      // Determine amount and currency based on selected account
      final double txAmount = _selectedAccount!.currency == CurrencyType.usd 
          ? widget.totalUSD 
          : (_selectedAccount!.currency == CurrencyType.eur 
              ? (widget.appState.euroRate > 0 ? (widget.totalVES / widget.appState.bcvRate) * widget.appState.euroRate : widget.totalUSD) // approximate EUR
              : widget.totalVES);

      final newTx = Transaction(
        id: widget.trip.transactionId ?? Uuid().v4(),
        date: DateTime.now(),
        amount: txAmount,
        currency: _selectedAccount!.currency,
        accountId: _selectedAccount!.id,
        categoryId: _selectedCategory!.id,
        note: _descriptionController.text,
        type: TransactionType.expense,
        exchangeRate: widget.appState.bcvRate,
      );

      if (widget.trip.transactionId != null) {
        // Edit existing transaction
        final matches = widget.appState.transactions.where((t) => t.id == widget.trip.transactionId);
        if (matches.isNotEmpty) {
          await widget.appState.updateTransaction(matches.first, newTx);
        } else {
          await widget.appState.addTransaction(newTx);
        }
      } else {
        // Create new transaction
        await widget.appState.addTransaction(newTx);
      }

      // Mark trip as inactive and link transaction ID
      widget.trip.isActive = false;
      widget.trip.transactionId = newTx.id;
      await widget.appState.updateMarketTrip(widget.trip);

      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sesión de compra finalizada")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al finalizar sesión: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show amount in selected currency
    String formattedTotal = "";
    if (_selectedAccount != null) {
      if (_selectedAccount!.currency == CurrencyType.usd) {
        formattedTotal = "\$${widget.totalUSD.toStringAsFixed(2)}";
      } else if (_selectedAccount!.currency == CurrencyType.eur) {
        final double eurAmt = widget.appState.euroRate > 0 ? (widget.totalVES / widget.appState.bcvRate) * widget.appState.euroRate : widget.totalUSD;
        formattedTotal = "${eurAmt.toStringAsFixed(2)} €";
      } else {
        formattedTotal = "Bs. ${widget.totalVES.toStringAsFixed(2)}";
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dialogBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 20.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Color(0xFFD6D6D6),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          ),
          SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Finalizar Compra",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Claymorphic Total Card
          ClaymorphicCard(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              children: [
                Text(
                  "TOTAL A REGISTRAR",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardSubtitleText,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  formattedTotal,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Equivalente a: \$${widget.totalUSD.toStringAsFixed(2)} / Bs. ${widget.totalVES.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Account selector dropdown
          Text(
            "Cuenta para el pago",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cardText),
          ),
          SizedBox(height: 4),
          DropdownButtonFormField<Account>(
            value: _selectedAccount,
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
            items: widget.appState.accounts.map((acc) {
              String symbol = acc.currency.symbol;
              return DropdownMenuItem(
                value: acc,
                child: Text("${acc.name} ($symbol ${acc.balance.toStringAsFixed(2)})"),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedAccount = val;
              });
            },
          ),
          SizedBox(height: 16),

          // Category selector dropdown
          Text(
            "Categoría del gasto",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cardText),
          ),
          SizedBox(height: 4),
          DropdownButtonFormField<TransactionCategory>(
            value: _selectedCategory,
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
            items: widget.appState.categories.map((cat) {
              return DropdownMenuItem(
                value: cat,
                child: Row(
                  children: [
                    if (cat.icon != null) ...[
                      Icon(getIconData(cat.icon!), color: AppColors.primary, size: 16),
                      SizedBox(width: 8),
                    ],
                    Text(cat.name),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedCategory = val;
              });
            },
          ),
          SizedBox(height: 16),

          // Description text field
          Text(
            "Descripción / Nota",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cardText),
          ),
          SizedBox(height: 4),
          TextField(
            controller: _descriptionController,
            style: TextStyle(fontSize: 13, color: AppColors.cardText),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: Colors.grey[100],
              hintText: "Descripción de la compra...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: 24),

          // Confirm button
          ElevatedButton(
            onPressed: _loading ? null : _finishSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    "FINALIZAR COMPRA",
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
          ),
        ],
      ),
    );
  }
}
