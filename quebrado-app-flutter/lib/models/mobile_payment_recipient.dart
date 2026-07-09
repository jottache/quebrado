import 'package:uuid/uuid.dart';

class MobilePaymentRecipient {
  final String id;
  String alias;
  String bankCode;
  String bankName;
  String identityCard;
  String phoneNumber;

  MobilePaymentRecipient({
    required this.id,
    required this.alias,
    required this.bankCode,
    required this.bankName,
    required this.identityCard,
    required this.phoneNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'alias': alias,
      'bank_code': bankCode,
      'bank_name': bankName,
      'identity_card': identityCard,
      'phone_number': phoneNumber,
    };
  }

  factory MobilePaymentRecipient.fromMap(Map<String, dynamic> map) {
    return MobilePaymentRecipient(
      id: map['id'] ?? const Uuid().v4(),
      alias: map['alias'] ?? '',
      bankCode: map['bank_code'] ?? '',
      bankName: map['bank_name'] ?? '',
      identityCard: map['identity_card'] ?? '',
      phoneNumber: map['phone_number'] ?? '',
    );
  }
}
