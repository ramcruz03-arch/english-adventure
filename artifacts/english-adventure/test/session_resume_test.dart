import 'dart:io';

import 'package:english_adventure/data/local/app_database.dart';
import 'package:english_adventure/data/local/sqflite_progress_repository.dart';
import 'package:english_adventure/domain/entities/activity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory databaseDirectory;
  late String databasePath;
  late Database database;
  late SqfliteProgressRepository progress;

  setUp(() async {
    databaseDirectory =
        await Directory.systemTemp.createTemp('english_adventure_test_');
    databasePath = '${databaseDirectory.path}/progress.db';
    database = await AppDatabase.open(path: databasePath);
    progress = SqfliteProgressRepository(database);
  });

  tearDown(() async {
    await database.close();
    await databaseDirectory.delete(recursive: true);
  });

  test('unfinished session restores its path, position, and stars', () async {
    final path = [
      const Activity(
        mode: GameMode.soundDetective,
        targetSkillId: 'g:s',
        tier: 2,
      ),
      const Activity(
        mode: GameMode.readSentence,
        targetSkillId: 'sentence',
        itemIds: ['w:sat', 'w:map'],
        content: ActivityContent.words(wordIds: ['w:sat', 'w:map']),
        isEasyWin: true,
      ),
    ];
    final sessionId = await progress.startSession('child_1', path: path);
    await progress.logAttempt(
      sessionId: sessionId,
      childId: 'child_1',
      mode: GameMode.soundDetective.name,
      skillId: 'g:s',
      outcome: 1,
      hintsUsed: 0,
    );
    await progress.saveSessionProgress(
      sessionId,
      currentActivity: 1,
      stars: 1,
    );

    // A fresh database connection models killing and reopening the app.
    await database.close();
    database = await AppDatabase.open(path: databasePath);
    progress = SqfliteProgressRepository(database);
    final resumed = await progress.unfinishedSession('child_1');

    expect(resumed, isNotNull);
    expect(resumed!.id, sessionId);
    expect(resumed.currentActivity, 1);
    expect(resumed.stars, 1);
    expect(resumed.path.length, 2);
    expect(resumed.path[0].targetSkillId, 'g:s');
    expect(resumed.path[1].content?.wordIds, ['w:sat', 'w:map']);
    expect(
      await database.rawQuery(
        'SELECT COUNT(*) AS count FROM attempt WHERE session_id = ?',
        [sessionId],
      ),
      contains(containsPair('count', 1)),
    );
  });

  test('completed sessions are not offered as interrupted', () async {
    final sessionId = await progress.startSession('child_1', path: const [
      Activity(mode: GameMode.traceWrite, targetSkillId: 'g:s'),
    ]);
    await progress.saveSessionProgress(
      sessionId,
      currentActivity: 1,
      stars: 1,
    );
    await progress.endSession(
      sessionId,
      seconds: 12,
      activities: 1,
      stars: 1,
      reason: 'complete',
    );

    expect(await progress.unfinishedSession('child_1'), isNull);
    final sessions = await database
        .query('session', where: 'id = ?', whereArgs: [sessionId]);
    expect(sessions.single['ended_reason'], 'complete');
    expect(sessions.single['activities_done'], 1);
  });

  test('negative checkpoints are normalized before activity advancement',
      () async {
    final sessionId = await progress.startSession('child_1', path: const [
      Activity(mode: GameMode.traceWrite, targetSkillId: 'g:s'),
      Activity(mode: GameMode.readSentence, targetSkillId: 'sentence'),
    ]);
    await database.update(
      'session',
      {'current_activity': -1},
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    final resumed = await progress.unfinishedSession('child_1');
    expect(resumed?.currentActivity, 0);
    expect(
      await progress.advanceSession(
        sessionId,
        expectedActivity: 0,
        nextActivity: 1,
        stars: 1,
      ),
      isTrue,
    );
    final session = await database
        .query('session', where: 'id = ?', whereArgs: [sessionId]);
    expect(session.single['current_activity'], 1);
  });

  test('database upgrade preserves earlier sessions and attempts', () async {
    await database.close();
    await File(databasePath).delete();

    final legacy = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE session (
            id TEXT PRIMARY KEY,
            child_id TEXT NOT NULL,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            seconds_active INTEGER NOT NULL DEFAULT 0,
            activities_done INTEGER NOT NULL DEFAULT 0,
            stars_earned INTEGER NOT NULL DEFAULT 0,
            ended_reason TEXT
          )''');
        await db.execute('''
          CREATE TABLE attempt (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            child_id TEXT NOT NULL,
            activity_mode TEXT NOT NULL,
            skill_id TEXT NOT NULL,
            outcome REAL NOT NULL,
            hints_used INTEGER NOT NULL DEFAULT 0,
            chosen_value TEXT,
            response_ms INTEGER,
            created_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE tracing_sample (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            child_id TEXT NOT NULL,
            glyph_id TEXT NOT NULL,
            coverage REAL,
            mean_deviation REAL,
            stroke_order_ok INTEGER,
            stroke_blob BLOB,
            created_at INTEGER NOT NULL
          )''');
      },
    );
    await legacy.insert('session', {
      'id': 'old_session',
      'child_id': 'child_1',
      'started_at': 1,
      'activities_done': 1,
      'stars_earned': 1,
    });
    await legacy.insert('attempt', {
      'session_id': 'old_session',
      'child_id': 'child_1',
      'activity_mode': GameMode.soundDetective.name,
      'skill_id': 'g:s',
      'outcome': 1,
      'hints_used': 0,
      'created_at': 1,
    });
    await legacy.close();

    database = await AppDatabase.open(path: databasePath);
    final sessions = await database.query('session');
    final attempts = await database.query('attempt');
    final columns = await database.rawQuery('PRAGMA table_info(session)');

    expect(sessions.single['id'], 'old_session');
    expect(sessions.single['activities_done'], 1);
    expect(attempts.single['session_id'], 'old_session');
    expect(columns.map((column) => column['name']),
        containsAll(['path_json', 'current_activity']));
  });

  test('delete all data clears every local child-data table', () async {
    await database.insert('child_profile', {
      'id': 'child_1',
      'display_name': 'Robin',
      'avatar_id': 'fox',
      'age_band': '6-8',
      'created_at': 1,
    });
    await database.insert('skill_state', {
      'child_id': 'child_1',
      'skill_id': 'g:s',
      'skill_type': 'grapheme',
      'status': 'learning',
    });
    final sessionId = await progress.startSession('child_1');
    await progress.logAttempt(
      sessionId: sessionId,
      childId: 'child_1',
      mode: GameMode.soundDetective.name,
      skillId: 'g:s',
      outcome: 1,
      hintsUsed: 0,
    );
    await progress.saveTracingSample(
      childId: 'child_1',
      glyphId: 'g:s',
      coverage: 0.9,
      meanDeviation: 0.1,
      strokeOrderOk: true,
    );
    await database.insert('reward_unlock', {
      'child_id': 'child_1',
      'reward_id': 'leaf_1',
      'unlocked_at': 1,
    });
    await database.insert('sync_queue', {
      'table_name': 'attempt',
      'row_key': '1',
      'op': 'upsert',
      'created_at': 1,
    });

    await progress.deleteAllData();

    for (final table in [
      'child_profile',
      'skill_state',
      'session',
      'attempt',
      'tracing_sample',
      'reward_unlock',
      'sync_queue',
    ]) {
      expect(await database.query(table), isEmpty, reason: table);
    }

    final freshSession = await progress.startSession('child_1');
    expect(freshSession, isNot(sessionId));
    expect(await database.query('session'), hasLength(1));
  });
}
