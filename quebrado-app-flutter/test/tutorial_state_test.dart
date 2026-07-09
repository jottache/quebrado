import 'package:flutter_test/flutter_test.dart';
import 'package:quebrado_app_flutter/viewmodels/app_state.dart';

void main() {
  test('AppState tutorial triggers and reset functionality', () async {
    final appState = AppState();

    // Verify initial values
    expect(appState.shouldShowDashboardTutorial, isFalse);
    expect(appState.shouldShowPocketsTutorial, isFalse);
    expect(appState.shouldShowTimelineTutorial, isFalse);
    expect(appState.shouldShowRecurrentsTutorial, isFalse);

    // Trigger dashboard tutorial
    appState.triggerDashboardTutorial();
    expect(appState.shouldShowDashboardTutorial, isTrue);
    expect(appState.currentTabIndex, equals(0));

    // Trigger pockets tutorial
    appState.triggerPocketsTutorial();
    expect(appState.shouldShowPocketsTutorial, isTrue);
    expect(appState.currentTabIndex, equals(1));
    expect(appState.initialPocketsSubTab, equals(0));

    // Trigger recurrents tutorial
    appState.triggerRecurrentsTutorial();
    expect(appState.shouldShowRecurrentsTutorial, isTrue);
    expect(appState.currentTabIndex, equals(1));
    expect(appState.initialPocketsSubTab, equals(1));

    // Trigger timeline tutorial
    appState.triggerTimelineTutorial();
    expect(appState.shouldShowTimelineTutorial, isTrue);
    expect(appState.currentTabIndex, equals(1));
    expect(appState.initialPocketsSubTab, equals(2));

    // Reset all tutorials (handles sqflite exception gracefully internally)
    await appState.resetAllTutorials();
    expect(appState.shouldShowDashboardTutorial, isFalse);
    expect(appState.shouldShowPocketsTutorial, isFalse);
    expect(appState.shouldShowTimelineTutorial, isFalse);
    expect(appState.shouldShowRecurrentsTutorial, isFalse);
  });
}
