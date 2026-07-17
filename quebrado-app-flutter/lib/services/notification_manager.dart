import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/recurring_payment.dart';
import '../models/transaction.dart';

class NotificationManager {
  static final NotificationManager shared = NotificationManager._internal();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  NotificationManager._internal();

  /// Initializes the local notification plugin and configures settings for Android/iOS.
  Future<void> initialize() async {
    tz.initializeTimeZones();

    // Android Settings: uses standard launcher icon resource name
    AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('launcher_icon');

    // iOS/Darwin Settings
    DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle tap if needed
      },
    );
  }

  /// Explicitly requests permission for push alerts on iOS.
  Future<void> requestAuthorization() async {
    // Request for iOS
    final bool? iosGranted = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Request for Android (Android 13+)
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Schedules a notification for a subscription based on its billing cycle.
  Future<void> scheduleNotification(RecurringPayment subscription, double bcvRate) async {
    // Cancel existing to prevent duplicates
    await cancelNotification(subscription);

    if (subscription.notificationOption == NotificationOption.none) return;

    final String symbol = subscription.currency.symbol;
    final String amountFormatted = "$symbol${subscription.amount.toStringAsFixed(2)}";

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'subscription_reminders',
      'Recordatorios de Suscripción',
      channelDescription: 'Canal para alertas de pago de suscripciones',
      importance: Importance.max,
      priority: Priority.high,
    );

    DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    DateTime targetDate = subscription.startDate;
    final now = DateTime.now();

    // Find the next future due date
    while (targetDate.isBefore(now)) {
      if (subscription.frequency == SubscriptionFrequency.once) {
        return; // Past one-time payment, do not schedule
      }
      switch (subscription.frequency) {
        case SubscriptionFrequency.weekly:
          targetDate = targetDate.add(Duration(days: 7));
          break;
        case SubscriptionFrequency.biweekly:
          targetDate = targetDate.add(Duration(days: 14));
          break;
        case SubscriptionFrequency.fifteenDays:
          if (targetDate.day == 15) {
            targetDate = DateTime(targetDate.year, targetDate.month + 1, 0, targetDate.hour, targetDate.minute, targetDate.second);
          } else if (targetDate.day > 15) {
            targetDate = DateTime(targetDate.year, targetDate.month + 1, 15, targetDate.hour, targetDate.minute, targetDate.second);
          } else {
            targetDate = DateTime(targetDate.year, targetDate.month, 15, targetDate.hour, targetDate.minute, targetDate.second);
          }
          break;
        case SubscriptionFrequency.monthly:
          targetDate = DateTime(targetDate.year, targetDate.month + 1, targetDate.day);
          break;
        case SubscriptionFrequency.threeMonths:
          targetDate = DateTime(targetDate.year, targetDate.month + 3, targetDate.day);
          break;
        case SubscriptionFrequency.yearly:
          targetDate = DateTime(targetDate.year + 1, targetDate.month, targetDate.day);
          break;
        case SubscriptionFrequency.custom:
          final days = subscription.customDays ?? 30;
          targetDate = targetDate.add(Duration(days: days > 0 ? days : 30));
          break;
        case SubscriptionFrequency.once:
          targetDate = now.add(Duration(days: 1)); // stop loop
          break;
      }
    }

    int offsetDays = 0;
    switch (subscription.notificationOption) {
      case NotificationOption.fiveDaysBefore:
        offsetDays = 5;
        break;
      case NotificationOption.oneDayBefore:
        offsetDays = 1;
        break;
      case NotificationOption.none:
        return;
    }

    DateTime notificationDate = targetDate.subtract(Duration(days: offsetDays));

    // If already passed, schedule 10 seconds into the future for debugging/alert fallback
    if (notificationDate.isBefore(now)) {
      if (targetDate.isAfter(now)) {
        notificationDate = now.add(Duration(seconds: 10));
      } else {
        return; // Both in the past, skip
      }
    }

    // Map UUID hashcode to integer notification ID
    final int notificationId = subscription.id.hashCode & 0x7FFFFFFF;

    // Convert DateTime to TZDateTime for local timezone scheduling
    final tz.TZDateTime tzNotificationDate = tz.TZDateTime.from(notificationDate, tz.local);

    final String titleLabel = subscription.frequency == SubscriptionFrequency.once
        ? 'Recordatorio de Pago'
        : 'Recordatorio de Suscripción';
    final String bodyLabel = subscription.frequency == SubscriptionFrequency.once
        ? 'Tu pago programado a ${subscription.name} ($amountFormatted) vence pronto.'
        : 'Tu suscripción a ${subscription.name} ($amountFormatted) vence pronto.';

    await _notificationsPlugin.zonedSchedule(
      notificationId,
      titleLabel,
      bodyLabel,
      tzNotificationDate,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    // Schedule actual due date notification at 8:00 AM (only if it is in the future)
    final tz.TZDateTime tzDueDate = tz.TZDateTime.from(
      DateTime(targetDate.year, targetDate.month, targetDate.day, 8, 0),
      tz.local,
    );
    if (tzDueDate.isAfter(now)) {
      final String dueTitle = subscription.frequency == SubscriptionFrequency.once
          ? (subscription.type == TransactionType.income ? 'Cobro programado hoy' : 'Pago programado hoy')
          : (subscription.type == TransactionType.income ? 'Ingreso programado hoy' : 'Gasto programado hoy');
      await _notificationsPlugin.zonedSchedule(
        (subscription.id.hashCode & 0x7FFFFFFF) + 2, // distinct ID for due day reminder
        dueTitle,
        'Hoy corresponde registrar: ${subscription.name} ($amountFormatted)',
        tzDueDate,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Cancels any scheduled notification for a subscription.
  Future<void> cancelNotification(RecurringPayment subscription) async {
    final int notificationId = subscription.id.hashCode & 0x7FFFFFFF;
    await _notificationsPlugin.cancel(notificationId);
    await _notificationsPlugin.cancel(notificationId + 2); // Cancel due day reminder too
  }

  /// Show immediate notification for today's due payment
  Future<void> showImmediateReminder(RecurringPayment payment) async {
    final String symbol = payment.currency.symbol;
    final String amountFormatted = "${payment.type == TransactionType.income ? '+' : '-'}$symbol${payment.amount.toStringAsFixed(2)}";

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'recurring_reminders_today',
      'Recordatorios del Día',
      channelDescription: 'Recordatorios para registrar ingresos y gastos de hoy',
      importance: Importance.max,
      priority: Priority.high,
    );

    DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final String immediateTitle = payment.frequency == SubscriptionFrequency.once
        ? (payment.type == TransactionType.income ? '¡Cobro programado hoy!' : '¡Pago programado hoy!')
        : (payment.type == TransactionType.income ? '¡Ingreso programado hoy!' : '¡Gasto programado hoy!');

    await _notificationsPlugin.show(
      (payment.id.hashCode & 0x7FFFFFFF) + 1, // distinct ID for immediate
      immediateTitle,
      'Es momento de registrar: ${payment.name} ($amountFormatted)',
      platformChannelSpecifics,
    );
  }
}
