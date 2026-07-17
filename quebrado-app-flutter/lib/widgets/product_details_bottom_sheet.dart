import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/market_product.dart';
import '../viewmodels/app_state.dart';
import '../theme/colors.dart';
import 'claymorphic_card.dart';

class ProductDetailsBottomSheet extends StatelessWidget {
  final MarketProduct product;

  const ProductDetailsBottomSheet({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottomInset > 0 ? bottomInset + 16 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            product.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            product.category,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.cardSubtitleText,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          Text(
            "Se consigue en:",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.cardText,
            ),
          ),
          SizedBox(height: 12),
          if (product.storeIds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Text(
                "Aún no hay registros de compra para este producto en ningún establecimiento.",
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.cardSubtitleText,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Expanded(
              child: DefaultTabController(
                length: product.storeIds.length,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: AppColors.primary,
                      dividerColor: Colors.transparent,
                      tabs: product.storeIds.map((storeId) {
                        final store = appState.marketStores.firstWhere(
                          (s) => s.id == storeId,
                          orElse: () => throw Exception('Store not found'),
                        );
                        return Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.storefront_rounded, size: 16),
                              SizedBox(width: 8),
                              Text(store.name),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: product.storeIds.map((storeId) {
                          final history = appState.getHistoricalPricesForProduct(product.id, storeId);

                          return SingleChildScrollView(
                            child: ClaymorphicCard(
                              padding: EdgeInsets.all(12),
                              cornerRadius: 16,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (history.isEmpty) ...[
                                    SizedBox(height: 8),
                                    Text(
                                      "No hay compras registradas",
                                      style: TextStyle(fontSize: 12, color: AppColors.cardSubtitleText),
                                    ),
                                  ] else ...[
                                    ...history.map((record) {
                                      final date = record['date'] as DateTime;
                                      final dateStr = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    record['tripTitle'],
                                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.cardText),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    dateStr,
                                                    style: TextStyle(fontSize: 10, color: AppColors.cardSubtitleText),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  "\$${(record['priceUSD'] as double).toStringAsFixed(2)}",
                                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.expense),
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  "${(record['priceVES'] as double).toStringAsFixed(2)} Bs.",
                                                  style: TextStyle(fontSize: 10, color: AppColors.cardSubtitleText),
                                                ),
                                                Text(
                                                  "Tasa: ${(record['exchangeRateUsed'] as double).toStringAsFixed(2)}",
                                                  style: TextStyle(fontSize: 9, color: Colors.blueGrey),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ]
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
