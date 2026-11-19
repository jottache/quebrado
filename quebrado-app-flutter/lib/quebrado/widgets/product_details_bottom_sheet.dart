import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/market_product.dart';
import '../viewmodels/app_state.dart';
import '../theme/colors.dart';
import 'helpers.dart';

import 'package:quebrado_app_flutter/theme/ortiz_space.dart';
import 'package:quebrado_app_flutter/theme/ortiz_tokens.dart';
import 'package:quebrado_app_flutter/theme/ortiz_type.dart';
import 'package:quebrado_app_flutter/widgets/ortiz/ortiz.dart';

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
        color: OrtizPalette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(OrtizRadius.sheet)),
      ),
      padding: EdgeInsets.only(
        left: OrtizSpace.lg,
        right: OrtizSpace.lg,
        top: OrtizSpace.lg,
        bottom: bottomInset > 0 ? bottomInset + OrtizSpace.lg : OrtizSpace.xxxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: OrtizPalette.faint,
                borderRadius: BorderRadius.circular(OrtizRadius.chip),
              ),
            ),
          ),
          SizedBox(height: OrtizSpace.lg),
          Text(
            product.name,
            style: TextStyle(
              fontSize: OrtizFontSize.title,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: OrtizSpace.xs),
          Text(
            product.category,
            style: TextStyle(
              fontSize: OrtizFontSize.bodySm,
              fontWeight: FontWeight.w600,
              color: AppColors.cardSubtitleText,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: OrtizSpace.xxl),
          Text(
            "Se consigue en:",
            style: TextStyle(
              fontSize: OrtizFontSize.titleSm,
              fontWeight: FontWeight.bold,
              color: AppColors.cardText,
            ),
          ),
          SizedBox(height: OrtizSpace.md),
          if (product.storeIds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: OrtizSpace.xxl),
              child: Text(
                "Aún no hay registros de compra para este producto en ningún establecimiento.",
                style: TextStyle(
                  fontSize: OrtizFontSize.bodySm,
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
                      unselectedLabelColor: OrtizPalette.muted,
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
                              const Icon(Icons.storefront_rounded, size: OrtizIconSize.sm),
                              SizedBox(width: OrtizSpace.sm),
                              Text(store.name),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: OrtizSpace.lg),
                    Expanded(
                      child: TabBarView(
                        children: product.storeIds.map((storeId) {
                          final history = appState.getHistoricalPricesForProduct(product.id, storeId);

                          return SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: OrtizSpace.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (history.isEmpty) ...[
                                    SizedBox(height: OrtizSpace.sm),
                                    Text(
                                      "No hay compras registradas",
                                      style: TextStyle(fontSize: OrtizFontSize.bodySm, color: AppColors.cardSubtitleText),
                                    ),
                                  ] else ...[
                                    ...history.map((record) {
                                      final date = record['date'] as DateTime;
                                      final dateStr = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: OrtizSpace.md),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    record['tripTitle'],
                                                    style: TextStyle(fontSize: OrtizFontSize.bodySm, fontWeight: FontWeight.w600, color: AppColors.cardText),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  SizedBox(height: OrtizSpace.xxs),
                                                  Text(
                                                    dateStr,
                                                    style: TextStyle(fontSize: OrtizFontSize.caption, color: AppColors.cardSubtitleText),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                OrtizAmount(
                                                  value: record['priceUSD'] as double,
                                                  currencySymbol: '\$',
                                                  format: formatUSD,
                                                  color: AppColors.expense,
                                                ),
                                                SizedBox(height: OrtizSpace.xxs),
                                                OrtizAmount(
                                                  value: record['priceVES'] as double,
                                                  currencySymbol: 'Bs.',
                                                  format: (v) => "${v.toStringAsFixed(2)} Bs.",
                                                  style: OrtizType.caption,
                                                  color: AppColors.cardSubtitleText,
                                                ),
                                                Text(
                                                  "Tasa: ${(record['exchangeRateUsed'] as double).toStringAsFixed(2)}",
                                                  style: TextStyle(fontSize: OrtizFontSize.caption, color: OrtizPalette.muted),
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
