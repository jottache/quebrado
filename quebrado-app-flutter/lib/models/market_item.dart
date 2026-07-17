import 'package:uuid/uuid.dart';

class MarketItem {
  final String id;
  String name;
  String category;
  double priceUSD;
  double priceVES;
  double exchangeRateUsed;
  String storeId;
  String tripId;
  String? productId;
  DateTime date;

  MarketItem({
    required this.id,
    required this.name,
    required this.category,
    required this.priceUSD,
    required this.priceVES,
    required this.exchangeRateUsed,
    required this.storeId,
    required this.tripId,
    this.productId,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price_usd': priceUSD,
      'price_ves': priceVES,
      'exchange_rate_used': exchangeRateUsed,
      'store_id': storeId,
      'trip_id': tripId,
      'product_id': productId,
      'date': date.toIso8601String(),
    };
  }

  factory MarketItem.fromMap(Map<String, dynamic> map) {
    return MarketItem(
      id: map['id'] ?? Uuid().v4(),
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      priceUSD: (map['price_usd'] as num?)?.toDouble() ?? 0.0,
      priceVES: (map['price_ves'] as num?)?.toDouble() ?? 0.0,
      exchangeRateUsed: (map['exchange_rate_used'] as num?)?.toDouble() ?? 0.0,
      storeId: map['store_id'] ?? '',
      tripId: map['trip_id'] ?? '',
      productId: map['product_id'],
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
    );
  }
}
