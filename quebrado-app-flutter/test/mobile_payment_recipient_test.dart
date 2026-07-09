import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/viewmodels/app_state.dart';
import 'package:quebrado_app_flutter/models/mobile_payment_recipient.dart';

void main() {
  test('AppState mobile payment recipient operations are correct', () async {
    final appState = AppState();

    // Verify initially empty
    expect(appState.recipients, isEmpty);

    // 1. Add a recipient
    await appState.addRecipient(
      alias: "Mamá Test",
      bankCode: "0134",
      bankName: "Banesco",
      identityCard: "V-12345678",
      phoneNumber: "04121234567",
    );

    expect(appState.recipients.length, equals(1));
    final added = appState.recipients.first;
    expect(added.alias, equals("Mamá Test"));
    expect(added.bankCode, equals("0134"));
    expect(added.bankName, equals("Banesco"));
    expect(added.identityCard, equals("V-12345678"));
    expect(added.phoneNumber, equals("04121234567"));

    // 2. Update the recipient
    final updatedRecipient = MobilePaymentRecipient(
      id: added.id,
      alias: "Mamá Actualizada",
      bankCode: "0102",
      bankName: "Banco de Venezuela",
      identityCard: "V-87654321",
      phoneNumber: "04147654321",
    );

    await appState.updateRecipient(updatedRecipient);

    expect(appState.recipients.length, equals(1));
    final updated = appState.recipients.first;
    expect(updated.alias, equals("Mamá Actualizada"));
    expect(updated.bankCode, equals("0102"));
    expect(updated.bankName, equals("Banco de Venezuela"));
    expect(updated.identityCard, equals("V-87654321"));
    expect(updated.phoneNumber, equals("04147654321"));

    // 3. Delete the recipient
    await appState.deleteRecipient(added.id);

    expect(appState.recipients, isEmpty);
  });
}
