import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Deliberately plain sqflite rather than Drift for the skeleton: no
/// build_runner, no codegen step, faster to get running on a modest laptop.
/// Everything sits behind ProgressRepository, so swapping in Drift later is a
/// data-layer change only.
class AppDatabase {
  static const _version = 4;
  static const _childDataTables = [
    'child_profile',
    'skill_state',
    'session',
    'attempt',
    'tracing_sample',
    'reward_unlock',
    'sync_queue',
  ];

  static Future<Database> open({String? path}) async {
    final databasePath =
        path ?? p.join(await getDatabasesPath(), 'english_adventure.db');
    return openDatabase(
      databasePath,
      version: _version,
      onCreate: (db, _) async => _createAll(db),
      onUpgrade: (db, from, to) async {
        if (from < 2) {
          await db.execute('ALTER TABLE session ADD COLUMN path_json TEXT');
          await db.execute(
              'ALTER TABLE session ADD COLUMN current_activity INTEGER NOT NULL DEFAULT 0');
        }
        if (from < 3) {
          await db.execute('ALTER TABLE attempt ADD COLUMN attempt_key TEXT');
          await db.execute(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_attempt_session_key ON attempt(session_id, attempt_key)');
        }
        if (from < 4) {
          await db
              .execute('ALTER TABLE tracing_sample ADD COLUMN sample_key TEXT');
          await db.execute(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_trace_child_key ON tracing_sample(child_id, sample_key)');
        }
      },
    );
  }

  static Future<void> _createAll(Database db) async {
    await db.execute('''
      CREATE TABLE child_profile (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        avatar_id TEXT NOT NULL,
        age_band TEXT NOT NULL,
        daily_goal_min INTEGER NOT NULL DEFAULT 12,
        accent TEXT NOT NULL DEFAULT 'en-GB',
        created_at INTEGER NOT NULL
      )''');

    await db.execute('''
      CREATE TABLE skill_state (
        child_id TEXT NOT NULL,
        skill_id TEXT NOT NULL,
        skill_type TEXT NOT NULL,
        status TEXT NOT NULL,
        ema REAL NOT NULL DEFAULT 0,
        exposures INTEGER NOT NULL DEFAULT 0,
        correct_count INTEGER NOT NULL DEFAULT 0,
        difficulty_tier INTEGER NOT NULL DEFAULT 1,
        leitner_box INTEGER NOT NULL DEFAULT 0,
        recent TEXT NOT NULL DEFAULT '',
        next_review_at INTEGER,
        last_seen_at INTEGER,
        PRIMARY KEY (child_id, skill_id)
      )''');
    await db.execute(
        'CREATE INDEX idx_skill_review ON skill_state(child_id, next_review_at)');

    await db.execute('''
      CREATE TABLE session (
        id TEXT PRIMARY KEY,
        child_id TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        seconds_active INTEGER NOT NULL DEFAULT 0,
        activities_done INTEGER NOT NULL DEFAULT 0,
        stars_earned INTEGER NOT NULL DEFAULT 0,
        ended_reason TEXT,
        path_json TEXT,
        current_activity INTEGER NOT NULL DEFAULT 0
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
        attempt_key TEXT,
        created_at INTEGER NOT NULL
      )''');
    await db.execute(
        'CREATE INDEX idx_attempt_child ON attempt(child_id, created_at)');
    await db.execute(
        'CREATE UNIQUE INDEX idx_attempt_session_key ON attempt(session_id, attempt_key)');

    await db.execute('''
      CREATE TABLE tracing_sample (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        child_id TEXT NOT NULL,
        glyph_id TEXT NOT NULL,
        coverage REAL,
        mean_deviation REAL,
        stroke_order_ok INTEGER,
        stroke_blob BLOB,
        sample_key TEXT,
        created_at INTEGER NOT NULL
      )''');
    await db.execute(
        'CREATE UNIQUE INDEX idx_trace_child_key ON tracing_sample(child_id, sample_key)');

    await db.execute('''
      CREATE TABLE reward_unlock (
        child_id TEXT NOT NULL,
        reward_id TEXT NOT NULL,
        unlocked_at INTEGER NOT NULL,
        PRIMARY KEY (child_id, reward_id)
      )''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        row_key TEXT NOT NULL,
        op TEXT NOT NULL,
        payload TEXT,
        created_at INTEGER NOT NULL
      )''');
  }

  /// Removes all locally stored child data in one transaction.
  ///
  /// Keeping this operation at the database boundary makes it harder for a
  /// future table to be accidentally omitted by a parent-facing caller.
  static Future<void> deleteAllChildData(Database db) async {
    await db.transaction((txn) async {
      for (final table in _childDataTables) {
        await txn.delete(table);
      }
    });
  }
}
