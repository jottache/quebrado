class HabitStackModel {
  final String id;
  final String? userId;
  final String name;
  final String timeOfDay; // 'morning', 'afternoon', 'evening', 'anytime'
  final String icon;
  final int position;
  final DateTime createdAt;

  HabitStackModel({
    required this.id,
    this.userId,
    required this.name,
    this.timeOfDay = 'morning',
    this.icon = 'layers',
    this.position = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get timeOfDayLabel {
    switch (timeOfDay) {
      case 'morning':
        return 'MAÑANA';
      case 'afternoon':
        return 'TARDE';
      case 'evening':
        return 'NOCHE';
      case 'anytime':
      default:
        return 'CUALQUIER HORA';
    }
  }

  HabitStackModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? timeOfDay,
    String? icon,
    int? position,
    DateTime? createdAt,
  }) {
    return HabitStackModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      icon: icon ?? this.icon,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'time_of_day': timeOfDay,
      'icon': icon,
      'position': position,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory HabitStackModel.fromMap(Map<String, dynamic> map) {
    return HabitStackModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      name: map['name']?.toString() ?? '',
      timeOfDay: map['time_of_day']?.toString() ?? 'morning',
      icon: map['icon']?.toString() ?? 'layers',
      position: (map['position'] is num) ? (map['position'] as num).toInt() : 0,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
