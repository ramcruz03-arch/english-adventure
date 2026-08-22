import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/accessibility/reading_prefs_controller.dart';
import '../core/audio/speech_service.dart';
import '../data/content/asset_content_repository.dart';
import '../data/local/app_database.dart';
import '../data/local/sqflite_progress_repository.dart';
import '../domain/repositories/content_repository.dart';
import '../domain/repositories/progress_repository.dart';
import '../domain/entities/resumable_session.dart';
import '../domain/usecases/build_daily_path.dart';
import '../domain/usecases/record_attempt.dart';
import 'theme.dart';

// Overridden in main() once async initialisation is done.
final databaseProvider = Provider<Database>((_) => throw UnimplementedError());
final sharedPrefsProvider =
    Provider<SharedPreferences>((_) => throw UnimplementedError());
final contentRepositoryProvider =
    Provider<ContentRepository>((_) => throw UnimplementedError());

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => SqfliteProgressRepository(ref.watch(databaseProvider)),
);

final speechProvider =
    Provider<SpeechService>((_) => TtsSpeechService(locale: 'en-GB'));

final recordAttemptProvider =
    Provider((ref) => RecordAttempt(ref.watch(progressRepositoryProvider)));

final unfinishedSessionProvider =
    FutureProvider.family<ResumableSession?, String>((ref, childId) =>
        ref.watch(progressRepositoryProvider).unfinishedSession(childId));

/// Bumped after a destructive local-data reset so cached progress views return
/// to the same empty state as the database.
final progressDataRevisionProvider = StateProvider<int>((_) => 0);

final buildDailyPathProvider = Provider((ref) => BuildDailyPath(
      ref.watch(contentRepositoryProvider),
      ref.watch(progressRepositoryProvider),
    ));

final readingPrefsProvider =
    StateNotifierProvider<ReadingPrefsController, ReadingPrefs>(
        (ref) => ReadingPrefsController(ref.watch(sharedPrefsProvider)));

/// Single active child. Profile switching lives behind the parent gate.
final activeChildProvider = StateProvider<String>((_) => 'child_1');

Future<List<Override>> buildOverrides() async {
  final db = await AppDatabase.open();
  final prefs = await SharedPreferences.getInstance();
  final content = AssetContentRepository();
  await content.load();
  return [
    databaseProvider.overrideWithValue(db),
    sharedPrefsProvider.overrideWithValue(prefs),
    contentRepositoryProvider.overrideWithValue(content),
  ];
}
