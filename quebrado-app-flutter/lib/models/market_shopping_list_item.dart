class MarketShoppingListItem {
  final String id;
  final String listId;
  final String productId;
  final bool isChecked;

  MarketShoppingListItem({
    required this.id,
    required this.listId,
    required this.productId,
    this.isChecked = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'list_id': listId,
      'product_id': productId,
      'is_checked': isChecked ? 1 : 0,
    };
  }

  factory MarketShoppingListItem.fromMap(Map<String, dynamic> map) {
    return MarketShoppingListItem(
      id: map['id'],
      listId: map['list_id'],
      productId: map['product_id'],
      isChecked: map['is_checked'] == 1,
    );
  }
}
