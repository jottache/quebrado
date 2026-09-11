import 'dart:convert';

class MarketProduct {
  final String id;
  String name;
  String category;
  List<String> storeIds; // IDs de los establecimientos donde se encuentra
  double? referencePriceUSD; // Opcional, último precio o precio de referencia
  String unit;
  double defaultQuantity;

  MarketProduct({
    required this.id,
    required this.name,
    required this.category,
    this.storeIds = const [],
    this.referencePriceUSD,
    this.unit = 'un',
    this.defaultQuantity = 1.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'storeIds': jsonEncode(storeIds),
      'referencePriceUSD': referencePriceUSD,
      'unit': unit,
      'default_quantity': defaultQuantity,
    };
  }

  factory MarketProduct.fromMap(Map<String, dynamic> map) {
    return MarketProduct(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      storeIds: map['storeIds'] != null ? List<String>.from(jsonDecode(map['storeIds'])) : [],
      referencePriceUSD: map['referencePriceUSD'],
      unit: map['unit'] ?? 'un',
      defaultQuantity: map['default_quantity'] ?? 1.0,
    );
  }
}
