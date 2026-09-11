class HabitLogModel {
  final String id;
  final String habitId;
  final String? userId;
  final String logDate; // Normalizado estrictamente a 'YYYY-MM-DD'
  final double value;
  final bool completed;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  HabitLogModel({
    required this.id,
    required this.habitId,
    this.userId,
    required this.logDate,
    this.value = 1.0,
    this.completed = false,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  HabitLogModel copyWith({
    String? id,
    String? habitId,
    String? userId,
    String? logDate,
    double? value,
    bool? completed,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HabitLogModel(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      userId: userId ?? this.userId,
      logDate: logDate ?? this.logDate,
      value: value ?? this.value,
      completed: completed ?? this.completed,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habit_id': habitId,
      'user_id': userId,
      'log_date': logDate,
      'value': value,
      'completed': completed,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HabitLogModel.fromMap(Map<String, dynamic> map) {
    return HabitLogModel(
      id: map['id']?.toString() ?? '',
      habitId: map['habit_id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      logDate: map['log_date']?.toString() ?? '',
      value: (map['value'] is num) ? (map['value'] as num).toDouble() : 1.0,
      completed: map['completed'] == true,
      notes: map['notes']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
