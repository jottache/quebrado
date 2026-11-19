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
import '../services/biometric_service.dart';
import '../widgets/add_market_store_bottom_sheet.dart';
import 'market_trip_store_screen.dart';
import 'package:uuid/uuid.dart';
import '../../widgets/responsive_breakpoints.dart';
import '../../widgets/responsive_sheet_helper.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

String _formatBsShort(double v) => "Bs ${v.toStringAsFixed(2)}";

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
    
    double totalUSD = 0.0;
    double totalVES = 0.0;

    if (itemsInTrip.isNotEmpty) {
      totalUSD = itemsInTrip.fold(0.0, (sum, i) => sum + i.priceUSD);
      totalVES = itemsInTrip.fold(0.0, (sum, i) => sum + i.priceVES);
    } else if (trip.transactionId != null) {
      final txMatches = appState.transactions.where((t) => t.id == trip.transactionId);
      if (txMatches.isNotEmpty) {
        final tx = txMatches.first;
        if (tx.currency == CurrencyType.usd) {
          totalUSD = tx.amount;
          totalVES = tx.amount * (tx.exchangeRate > 0 ? tx.exchangeRate : appState.bcvRate);
        } else {
          totalVES = tx.amount;
          final rate = tx.exchangeRate > 0 ? tx.exchangeRate : appState.bcvRate;
          totalUSD = rate > 0 ? tx.amount / rate : 0.0;
        }
      }
    }

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
            icon: const Icon(Icons.delete_outline, color: OrtizPalette.bad),
            tooltip: 'Eliminar sesión',
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
                          "TOTAL SESIÓN",
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OrtizSpace.lg, vertical: OrtizSpace.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Tus Compras",
                  style: OrtizType.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: OrtizPalette.muted,
                  ),
                ),
              ),
            ),
            Expanded(
              child: itemsByStore.isEmpty
                  ? OrtizEmptyState(
                      icon: trip.transactionId != null ? Icons.receipt_long : Icons.storefront_outlined,
                      title: trip.transactionId != null
                          ? "Sesión Registrada"
                          : "Sin Productos Registrados",
                      message: trip.transactionId != null
                          ? "Esta sesión fue finalizada y guardada como un gasto de \$${totalUSD.toStringAsFixed(2)} (Bs ${totalVES.toStringAsFixed(2)}).\n\nLos ítems individuales no estaban desglosados en este respaldo, pero el monto total del gasto está guardado en tu cuenta."
                          : "No has registrado compras en ningún establecimiento.",
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(OrtizSpace.lg, 0, OrtizSpace.lg, OrtizSpace.xxxl),
                      separatorBuilder: (context, index) => const Divider(height: OrtizStroke.hairline),
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
                        
                        return ortizStaggered(
                          context,
                          index,
                          OrtizListRow(
                            leading: const Icon(Icons.storefront),
                            title: store.name,
                            subtitle: "${storeItems.length} productos",
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
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OrtizAmount(
                                  value: storeTotalUSD,
                                  currencySymbol: '\$',
                                  format: formatUSD,
                                ),
                                OrtizAmount(
                                  value: storeTotalVES,
                                  currencySymbol: 'Bs',
                                  format: _formatBsShort,
                                  style: OrtizType.caption,
                                  color: OrtizPalette.muted,
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(OrtizSpace.lg),
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
                      fontSize: OrtizFontSize.bodySm,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OrtizPalette.surfaceHigh,
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: OrtizSpace.lg),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.block),
                    ),
                  ),
                ),
              ),
              SizedBox(height: OrtizSpace.sm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    _confirmFinishTrip(context, appState, trip);
                  },
                  icon: Icon(Icons.check_circle, color: OrtizPalette.onAccent),
                  label: Text(
                    "FINALIZAR SESIÓN",
                    style: TextStyle(color: OrtizPalette.onAccent, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: OrtizFontSize.bodySm),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: OrtizPalette.onAccent,
                    padding: EdgeInsets.symmetric(vertical: OrtizSpace.lg),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.block),
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
                  icon: Icon(Icons.refresh, color: OrtizPalette.onAccent),
                  label: Text(
                    "REABRIR SESIÓN",
                    style: TextStyle(color: OrtizPalette.onAccent, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: OrtizFontSize.bodySm),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: OrtizPalette.onAccent,
                    padding: EdgeInsets.symmetric(vertical: OrtizSpace.lg),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(OrtizRadius.block),
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

    showResponsiveSheet(
      context: context,
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
    showResponsiveSheet(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
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
                "Selecciona un establecimiento",
                style: TextStyle(
                  fontSize: OrtizFontSize.title,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: OrtizSpace.lg),
                itemCount: appState.marketStores.length,
                itemBuilder: (context, index) {
                  final store = appState.marketStores[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: OrtizSpace.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(OrtizSpace.lg),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Icon(Icons.storefront, color: AppColors.primary),
                        ),
                        title: Text(
                          store.name,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: Icon(Icons.chevron_right, color: OrtizPalette.muted),
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
                padding: const EdgeInsets.all(OrtizSpace.lg),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      showResponsiveSheet(
                        context: context,
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
                        fontSize: OrtizFontSize.bodySm,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: OrtizPalette.onAccent,
                      padding: EdgeInsets.symmetric(vertical: OrtizSpace.lg),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OrtizRadius.block),
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
                "¿Eliminar Sesión?",
                style: TextStyle(
                  fontSize: OrtizFontSize.title,
                  fontWeight: FontWeight.bold,
                  color: OrtizPalette.bad,
                ),
              ),
              SizedBox(height: OrtizSpace.md),
              Text(
                "Se eliminarán todos los productos registrados en esta sesión. Esta acción no se puede deshacer.",
                textAlign: TextAlign.center,
                style: TextStyle(color: OrtizPalette.muted),
              ),
              SizedBox(height: OrtizSpace.xxl),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancelar", style: TextStyle(color: OrtizPalette.muted, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(width: OrtizSpace.lg),
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
                        backgroundColor: OrtizPalette.bad,
                        foregroundColor: OrtizPalette.onAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(OrtizRadius.field),
                        ),
                        padding: EdgeInsets.symmetric(vertical: OrtizSpace.md),
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
      final authenticated = await widget.appState.verifySecurityAuth(
        context,
        reason: 'Confirma tu identidad para registrar esta compra',
      );
      if (!authenticated) {
        setState(() {
          _loading = false;
        });
        return;
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
          topLeft: Radius.circular(OrtizRadius.pill),
          topRight: Radius.circular(OrtizRadius.pill),
        ),
      ),
      padding: EdgeInsets.only(
        left: OrtizSpace.lg,
        right: OrtizSpace.lg,
        top: OrtizSpace.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + OrtizSpace.xl,
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
                color: OrtizPalette.line,
                borderRadius: BorderRadius.all(Radius.circular(OrtizRadius.chip)),
              ),
            ),
          ),
          SizedBox(height: OrtizSpace.lg),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Finalizar Compra",
                style: TextStyle(
                  fontSize: OrtizFontSize.title,
                  fontWeight: FontWeight.w900,
                  color: OrtizPalette.fg,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: OrtizSpace.lg),

          // Claymorphic Total Card
          Padding(
            padding: EdgeInsets.symmetric(vertical: OrtizSpace.xl, horizontal: OrtizSpace.lg),
            child: Column(
              children: [
                Text(
                  "TOTAL A REGISTRAR",
                  style: TextStyle(
                    fontSize: OrtizFontSize.caption,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cardSubtitleText,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: OrtizSpace.sm),
                Text(
                  formattedTotal,
                  style: TextStyle(
                    fontSize: OrtizFontSize.displayLg,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: OrtizSpace.xs),
                Text(
                  "Equivalente a: \$${widget.totalUSD.toStringAsFixed(2)} / Bs. ${widget.totalVES.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: OrtizFontSize.bodySm,
                    color: OrtizPalette.muted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: OrtizSpace.xl),

          // Account selector dropdown
          Text(
            "Cuenta para el pago",
            style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.cardText),
          ),
          SizedBox(height: OrtizSpace.xs),
          DropdownButtonFormField<Account>(
            value: _selectedAccount,
            isExpanded: true,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
              filled: true,
              fillColor: OrtizPalette.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                borderSide: BorderSide.none,
              ),
            ),
            dropdownColor: OrtizPalette.surface,
            style: TextStyle(color: AppColors.cardText, fontSize: OrtizFontSize.bodySm),
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
          SizedBox(height: OrtizSpace.lg),

          // Category selector dropdown
          Text(
            "Categoría del gasto",
            style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.cardText),
          ),
          SizedBox(height: OrtizSpace.xs),
          DropdownButtonFormField<TransactionCategory>(
            value: _selectedCategory,
            isExpanded: true,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.sm),
              filled: true,
              fillColor: OrtizPalette.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                borderSide: BorderSide.none,
              ),
            ),
            dropdownColor: OrtizPalette.surface,
            style: TextStyle(color: AppColors.cardText, fontSize: OrtizFontSize.bodySm),
            items: widget.appState.categories.map((cat) {
              return DropdownMenuItem(
                value: cat,
                child: Row(
                  children: [
                    if (cat.icon != null) ...[
                      Icon(getIconData(cat.icon!), color: AppColors.primary, size: OrtizIconSize.sm),
                      SizedBox(width: OrtizSpace.sm),
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
          SizedBox(height: OrtizSpace.lg),

          // Description text field
          Text(
            "Descripción / Nota",
            style: TextStyle(fontSize: OrtizFontSize.caption, fontWeight: FontWeight.bold, color: AppColors.cardText),
          ),
          SizedBox(height: OrtizSpace.xs),
          TextField(
            controller: _descriptionController,
            style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardText),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: OrtizSpace.md, vertical: OrtizSpace.md),
              filled: true,
              fillColor: OrtizPalette.surfaceHigh,
              hintText: "Descripción de la compra...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: OrtizSpace.xxl),

          // Confirm button
          ElevatedButton(
            onPressed: _loading ? null : _finishSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: OrtizPalette.onAccent,
              padding: EdgeInsets.symmetric(vertical: OrtizSpace.lg),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(OrtizRadius.field),
              ),
            ),
            child: _loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: OrtizPalette.onAccent,
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
