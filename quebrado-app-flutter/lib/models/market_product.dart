import 'dart:convert';

class MarketProduct {
  final String id;
  String name;
  String category;
  List<String> storeIds; // IDs de los establecimientos donde se encuentra
  double? referencePriceUSD; // Opcional, último precio o precio de referencia

  MarketProduct({
    required this.id,
    required this.name,
    required this.category,
    this.storeIds = const [],
    this.referencePriceUSD,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'storeIds': jsonEncode(storeIds),
      'referencePriceUSD': referencePriceUSD,
    };
  }

  factory MarketProduct.fromMap(Map<String, dynamic> map) {
    return MarketProduct(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      storeIds: map['storeIds'] != null ? List<String>.from(jsonDecode(map['storeIds'])) : [],
      referencePriceUSD: map['referencePriceUSD'],
    );
  }
}
