import 'package:english_adventure/app/providers.dart';
import 'package:english_adventure/domain/entities/activity.dart';
import 'package:english_adventure/domain/entities/resumable_session.dart';
import 'package:english_adventure/domain/entities/skill_state.dart';
import 'package:english_adventure/domain/repositories/progress_repository.dart';
import 'package:english_adventure/presentation/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  testWidgets(
      'parent-gated delete all data asks for confirmation and returns home',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final progress = _InMemoryProgress();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWithValue(progress),
          sharedPrefsProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continue your adventure'), findsOneWidget);

    await tester.tap(find.byTooltip('Parents'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1985');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final deleteButton = find.text('Delete all data');
    expect(deleteButton, findsOneWidget);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('Delete all data?'), findsOneWidget);
    expect(find.text('Delete everything'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(progress.deleted, isFalse);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(progress.deleted, isTrue);
    expect(find.text('Today\'s Adventure'), findsOneWidget);
  });
}

class _InMemoryProgress implements ProgressRepository {
  _InMemoryProgress()
      : _unfinished = ResumableSession(
          id: 'saved_session',
          childId: 'child_1',
          startedAt: DateTime(2026),
          path: const [],
          currentActivity: 0,
          stars: 0,
        );

  bool deleted = false;
  ResumableSession? _unfinished;

  @override
  Future<bool> advanceSession(
    String sessionId, {
    required int expectedActivity,
    required int nextActivity,
    required int stars,
  }) async =>
      true;

  @override
  Future<List<SkillState>> allSkills(String childId) async => [];

  @override
  Future<void> deleteAllData() async {
    deleted = true;
    _unfinished = null;
  }

  @override
  Future<void> endSession(
    String sessionId, {
    required int seconds,
    required int activities,
    required int stars,
    required String reason,
  }) async {}

  @override
  Future<double> lastSessionAccuracy(String childId) async => 1;

  @override
  Future<bool> logAttempt({
    required String sessionId,
    required String childId,
    required String mode,
    required String skillId,
    required double outcome,
    required int hintsUsed,
    String? attemptKey,
    String? chosenValue,
    int? responseMs,
  }) async =>
      true;

  @override
  Future<bool> recordSkillAttempt({
    required SkillState updatedState,
    required String sessionId,
    required String childId,
    required String mode,
    required String skillId,
    required double outcome,
    required int hintsUsed,
    required String attemptKey,
    String? chosenValue,
    int? responseMs,
  }) async =>
      true;

  @override
  Future<void> saveSessionPlan(String sessionId, List<Activity> path) async {}

  @override
  Future<void> saveSessionProgress(
    String sessionId, {
    required int currentActivity,
    required int stars,
  }) async {}

  @override
  Future<void> saveSkill(SkillState state) async {}

  @override
  Future<void> saveTracingSample({
    required String childId,
    required String glyphId,
    required double coverage,
    required double meanDeviation,
    required bool strokeOrderOk,
    String? sampleKey,
  }) async {}

  @override
  Future<SkillState> skill(
    String childId,
    String skillId,
    String skillType,
  ) async =>
      SkillState(
        childId: childId,
        skillId: skillId,
        skillType: skillType,
      );

  @override
  Future<String> startSession(
    String childId, {
    List<Activity> path = const [],
  }) async =>
      'session';

  @override
  Future<ResumableSession?> unfinishedSession(String childId) async =>
      _unfinished;
}
