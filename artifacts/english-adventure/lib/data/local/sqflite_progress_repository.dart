import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/resumable_session.dart';
import '../../domain/entities/skill_state.dart';
import '../../domain/repositories/progress_repository.dart';

class SqfliteProgressRepository implements ProgressRepository {
  SqfliteProgressRepository(this._db);
  final Database _db;

  @override
  Future<void> deleteAllData() => AppDatabase.deleteAllChildData(_db);

  @override
  Future<SkillState> skill(
      String childId, String skillId, String skillType) async {
    final rows = await _db.query('skill_state',
        where: 'child_id = ? AND skill_id = ?',
        whereArgs: [childId, skillId],
        limit: 1);
    if (rows.isEmpty) {
      return SkillState(
          childId: childId, skillId: skillId, skillType: skillType);
    }
    return _fromRow(rows.first);
  }

  @override
  Future<List<SkillState>> allSkills(String childId) async {
    final rows = await _db
        .query('skill_state', where: 'child_id = ?', whereArgs: [childId]);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> saveSkill(SkillState s) async {
    await _db.insert(
      'skill_state',
      _skillValues(s),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

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
  }) {
    return _db.transaction((txn) async {
      final existing = await txn.query(
        'attempt',
        columns: const ['id'],
        where: 'session_id = ? AND attempt_key = ?',
        whereArgs: [sessionId, attemptKey],
        limit: 1,
      );
      if (existing.isNotEmpty) return false;

      await txn.insert(
        'skill_state',
        _skillValues(updatedState),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert('attempt', {
        'session_id': sessionId,
        'child_id': childId,
        'activity_mode': mode,
        'skill_id': skillId,
        'outcome': outcome,
        'hints_used': hintsUsed,
        'chosen_value': chosenValue,
        'response_ms': responseMs,
        'attempt_key': attemptKey,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    });
  }

  @override
  Future<String> startSession(String childId,
      {List<Activity> path = const []}) async {
    final id = 's_${DateTime.now().microsecondsSinceEpoch}';
    await _db.insert('session', {
      'id': id,
      'child_id': childId,
      'started_at': DateTime.now().millisecondsSinceEpoch,
      if (path.isNotEmpty)
        'path_json':
            jsonEncode(path.map((activity) => activity.toJson()).toList()),
    });
    return id;
  }

  @override
  Future<ResumableSession?> unfinishedSession(String childId) async {
    final rows = await _db.query(
      'session',
      where: 'child_id = ? AND ended_at IS NULL AND path_json IS NOT NULL',
      whereArgs: [childId],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;

    try {
      final row = rows.first;
      final rawPath = jsonDecode(row['path_json'] as String) as List;
      final path = rawPath
          .map((item) =>
              Activity.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      var current = (row['current_activity'] as num?)?.toInt() ?? 0;
      if (current < 0) {
        await _db.update(
          'session',
          {'current_activity': 0, 'activities_done': 0},
          where: 'id = ? AND ended_at IS NULL',
          whereArgs: [row['id']],
        );
        current = 0;
      }
      if (path.isEmpty || current >= path.length) {
        await endSession(
          row['id'] as String,
          seconds: 0,
          activities: current,
          stars: (row['stars_earned'] as num?)?.toInt() ?? 0,
          reason: 'complete',
        );
        return null;
      }
      return ResumableSession(
        id: row['id'] as String,
        childId: row['child_id'] as String,
        startedAt:
            DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
        path: path,
        currentActivity: current,
        stars: (row['stars_earned'] as num?)?.toInt() ?? 0,
      );
    } on Object {
      await endSession(
        rows.first['id'] as String,
        seconds: 0,
        activities: 0,
        stars: (rows.first['stars_earned'] as num?)?.toInt() ?? 0,
        reason: 'checkpoint_unreadable',
      );
      return null;
    }
  }

  @override
  Future<void> saveSessionPlan(String sessionId, List<Activity> path) async {
    await _db.update(
      'session',
      {'path_json': jsonEncode(path.map((a) => a.toJson()).toList())},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  @override
  Future<void> saveSessionProgress(String sessionId,
      {required int currentActivity, required int stars}) async {
    await _db.rawUpdate(
      '''UPDATE session SET
           current_activity = CASE WHEN current_activity > ? THEN current_activity ELSE ? END,
           stars_earned = CASE WHEN stars_earned > ? THEN stars_earned ELSE ? END,
           activities_done = CASE WHEN activities_done > ? THEN activities_done ELSE ? END
         WHERE id = ? AND ended_at IS NULL''',
      [
        currentActivity,
        currentActivity,
        stars,
        stars,
        currentActivity,
        currentActivity,
        sessionId,
      ],
    );
  }

  @override
  Future<bool> advanceSession(String sessionId,
      {required int expectedActivity,
      required int nextActivity,
      required int stars}) async {
    final changed = await _db.rawUpdate(
      '''UPDATE session
         SET current_activity = ?, activities_done = ?, stars_earned = ?
         WHERE id = ? AND ended_at IS NULL AND current_activity = ?''',
      [nextActivity, nextActivity, stars, sessionId, expectedActivity],
    );
    return changed == 1;
  }

  @override
  Future<void> endSession(String sessionId,
      {required int seconds,
      required int activities,
      required int stars,
      required String reason}) async {
    await _db.update(
      'session',
      {
        'ended_at': DateTime.now().millisecondsSinceEpoch,
        'seconds_active': seconds,
        'activities_done': activities,
        'stars_earned': stars,
        'ended_reason': reason,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

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
  }) async {
    final id = await _db.insert(
        'attempt',
        {
          'session_id': sessionId,
          'child_id': childId,
          'activity_mode': mode,
          'skill_id': skillId,
          'outcome': outcome,
          'hints_used': hintsUsed,
          'chosen_value': chosenValue,
          'response_ms': responseMs,
          'attempt_key': attemptKey,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    return id != 0;
  }

  @override
  Future<double> lastSessionAccuracy(String childId) async {
    final sessions = await _db.query('session',
        where: 'child_id = ? AND ended_at IS NOT NULL',
        whereArgs: [childId],
        orderBy: 'started_at DESC',
        limit: 1);
    if (sessions.isEmpty) return 1.0; // first ever session: go ahead and teach

    final rows = await _db.rawQuery('''SELECT AVG(outcome) AS a FROM attempt
           WHERE session_id = ?
           AND activity_mode NOT IN ('readSentence', 'miniStory')''',
        [sessions.first['id']]);
    return (rows.first['a'] as num?)?.toDouble() ?? 1.0;
  }

  @override
  Future<void> saveTracingSample({
    required String childId,
    required String glyphId,
    required double coverage,
    required double meanDeviation,
    required bool strokeOrderOk,
    String? sampleKey,
  }) async {
    await _db.insert(
        'tracing_sample',
        {
          'child_id': childId,
          'glyph_id': glyphId,
          'coverage': coverage,
          'mean_deviation': meanDeviation,
          'stroke_order_ok': strokeOrderOk ? 1 : 0,
          'sample_key': sampleKey,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Map<String, Object?> _skillValues(SkillState s) => {
        'child_id': s.childId,
        'skill_id': s.skillId,
        'skill_type': s.skillType,
        'status': s.status.name,
        'ema': s.ema,
        'exposures': s.exposures,
        'correct_count': s.correctCount,
        'difficulty_tier': s.difficultyTier,
        'leitner_box': s.leitnerBox,
        'recent': s.recent.join(','),
        'next_review_at': s.nextReviewAt?.millisecondsSinceEpoch,
        'last_seen_at': s.lastSeenAt?.millisecondsSinceEpoch,
      };

  SkillState _fromRow(Map<String, Object?> r) => SkillState(
        childId: r['child_id'] as String,
        skillId: r['skill_id'] as String,
        skillType: r['skill_type'] as String,
        status: SkillStatus.values.firstWhere((s) => s.name == r['status'],
            orElse: () => SkillStatus.untouched),
        ema: (r['ema'] as num).toDouble(),
        exposures: r['exposures'] as int,
        correctCount: r['correct_count'] as int,
        difficultyTier: r['difficulty_tier'] as int,
        leitnerBox: r['leitner_box'] as int,
        recent: (r['recent'] as String)
            .split(',')
            .where((e) => e.isNotEmpty)
            .map(double.parse)
            .toList(),
        nextReviewAt: r['next_review_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r['next_review_at'] as int),
        lastSeenAt: r['last_seen_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r['last_seen_at'] as int),
      );
}
