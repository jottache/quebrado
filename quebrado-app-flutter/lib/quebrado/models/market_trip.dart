import 'package:uuid/uuid.dart';

class MarketTrip {
  final String id;
  String title;
  DateTime date;
  bool isActive;
  String? transactionId;

  MarketTrip({
    required this.id,
    required this.title,
    required this.date,
    this.isActive = true,
    this.transactionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'transaction_id': transactionId,
    };
  }

  factory MarketTrip.fromMap(Map<String, dynamic> map) {
    return MarketTrip(
      id: map['id'] ?? Uuid().v4(),
      title: map['title'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      isActive: map['is_active'] == 1,
      transactionId: map['transaction_id'],
    );
  }
}
