class MarketShoppingList {
  final String id;
  final String title;
  final DateTime date;
  final bool isActive;

  MarketShoppingList({
    required this.id,
    required this.title,
    required this.date,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory MarketShoppingList.fromMap(Map<String, dynamic> map) {
    return MarketShoppingList(
      id: map['id'],
      title: map['title'],
      date: DateTime.parse(map['date']),
      isActive: map['is_active'] == 1,
    );
  }
}
