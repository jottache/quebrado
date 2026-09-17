class DiarioContact {
  final String id;
  final String name;
  final String? nickname;
  final String? relationship;
  final String? avatarUrl;
  final String? avatarColor;
  final DateTime? birthdate;
  final String? phone;
  final String? notes;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiarioContact({
    required this.id,
    required this.name,
    this.nickname,
    this.relationship,
    this.avatarUrl,
    this.avatarColor,
    this.birthdate,
    this.phone,
    this.notes,
    this.isFavorite = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get displayName {
    if (nickname != null && nickname!.trim().isNotEmpty) {
      return '$name ("$nickname")';
    }
    return name;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  int? get daysUntilBirthday {
    if (birthdate == null) return null;
    final now = DateTime.now();
    final thisYearBday = DateTime(now.year, birthdate!.month, birthdate!.day);
    if (thisYearBday.isAtSameMomentAs(DateTime(now.year, now.month, now.day))) {
      return 0; // Hoy es su cumpleaños
    }
    if (thisYearBday.isAfter(now)) {
      return thisYearBday.difference(DateTime(now.year, now.month, now.day)).inDays;
    }
    final nextYearBday = DateTime(now.year + 1, birthdate!.month, birthdate!.day);
    return nextYearBday.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  int? get currentAge {
    if (birthdate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthdate!.year;
    if (now.month < birthdate!.month || (now.month == birthdate!.month && now.day < birthdate!.day)) {
      age--;
    }
    return age;
  }

  int? get ageOnUpcomingBirthday {
    if (birthdate == null) return null;
    final age = currentAge;
    if (age == null) return null;
    final days = daysUntilBirthday;
    if (days == null) return null;
    return days == 0 ? age : age + 1;
  }

  String? get formattedBirthdate {
    if (birthdate == null) return null;
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${birthdate!.day} de ${months[birthdate!.month - 1]}';
  }

  DiarioContact copyWith({
    String? id,
    String? name,
    String? nickname,
    bool clearNickname = false,
    String? relationship,
    bool clearRelationship = false,
    String? avatarUrl,
    bool clearAvatar = false,
    String? avatarColor,
    DateTime? birthdate,
    bool clearBirthdate = false,
    String? phone,
    bool clearPhone = false,
    String? notes,
    bool clearNotes = false,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiarioContact(
      id: id ?? this.id,
      name: name ?? this.name,
      nickname: clearNickname ? null : (nickname ?? this.nickname),
      relationship: clearRelationship ? null : (relationship ?? this.relationship),
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      avatarColor: avatarColor ?? this.avatarColor,
      birthdate: clearBirthdate ? null : (birthdate ?? this.birthdate),
      phone: clearPhone ? null : (phone ?? this.phone),
      notes: clearNotes ? null : (notes ?? this.notes),
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nickname': nickname,
      'relationship': relationship,
      'avatar_url': avatarUrl,
      'avatar_color': avatarColor,
      'birthdate': birthdate?.toIso8601String().split('T').first,
      'phone': phone,
      'notes': notes,
      'is_favorite': isFavorite,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DiarioContact.fromMap(Map<String, dynamic> map) {
    DateTime? bday;
    if (map['birthdate'] != null) {
      try {
        bday = DateTime.parse(map['birthdate'].toString());
      } catch (_) {}
    }

    return DiarioContact(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      nickname: map['nickname']?.toString(),
      relationship: map['relationship']?.toString(),
      avatarUrl: map['avatar_url']?.toString(),
      avatarColor: map['avatar_color']?.toString(),
      birthdate: bday,
      phone: map['phone']?.toString(),
      notes: map['notes']?.toString(),
      isFavorite: map['is_favorite'] == true || map['is_favorite'] == 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
