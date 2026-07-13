import 'package:uuid/uuid.dart';

class MarketStore {
  final String id;
  String name;
  String? description;
  String? colorHex;
  String? icon;

  MarketStore({
    required this.id,
    required this.name,
    this.description,
    this.colorHex,
    this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color_hex': colorHex,
      'icon': icon,
    };
  }

  factory MarketStore.fromMap(Map<String, dynamic> map) {
    return MarketStore(
      id: map['id'] ?? Uuid().v4(),
      name: map['name'] ?? '',
      description: map['description'],
      colorHex: map['color_hex'],
      icon: map['icon'],
    );
  }
}
