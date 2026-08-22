import 'activity.dart';

/// The local checkpoint needed to resume a child session after an interruption.
class ResumableSession {
  const ResumableSession({
    required this.id,
    required this.childId,
    required this.startedAt,
    required this.path,
    required this.currentActivity,
    required this.stars,
  });

  final String id;
  final String childId;
  final DateTime startedAt;
  final List<Activity> path;
  final int currentActivity;
  final int stars;
}