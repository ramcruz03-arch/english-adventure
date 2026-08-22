import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/entities/skill_state.dart';
import '../session/session_screen.dart';
import '../parent/parent_dashboard_screen.dart';
import '../shared/big_button.dart';
import '../shared/guide.dart';

/// Home is a garden, not a dashboard.
///
/// Progress is shown as a growing vine - one leaf per mastered sound. No
/// numbers, no percentages, no streak, no comparison. A child who has been
/// away for a week comes back to the same vine, not to a broken streak.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childId = ref.watch(activeChildProvider);
    final skills = ref.watch(_skillsProvider(childId));
    final resume = ref.watch(unfinishedSessionProvider(childId));
    final savedSession = resume.asData?.value;
    final checkingSession = resume.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    iconSize: 34,
                    onPressed: () => _parentGate(context),
                    icon: const Icon(Icons.settings_rounded,
                        color: Tokens.inkSoft),
                    tooltip: 'Parents',
                  ),
                ],
              ),
              const AnilGuide(size: 96, line: 'Ready for today\'s adventure?'),
              const SizedBox(height: 24),
              Expanded(
                child: skills.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (list) => _Vine(
                    mastered: list
                        .where((s) =>
                            s.skillType == 'grapheme' &&
                            s.status == SkillStatus.mastered)
                        .length,
                  ),
                ),
              ),
              BigButton(
                label: checkingSession
                    ? 'Getting your adventure ready'
                    : resume.hasError
                        ? 'Try again'
                        : savedSession == null
                            ? 'Today\'s Adventure'
                            : 'Continue your adventure',
                onPressed: checkingSession
                    ? null
                    : resume.hasError
                        ? () =>
                            ref.invalidate(unfinishedSessionProvider(childId))
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    SessionScreen(resumeSession: savedSession),
                              ),
                            ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Parent gate: a task a 5-9 year old cannot complete but an adult finds
  /// trivial. Never a simple "tap twice to continue".
  void _parentGate(BuildContext context) {
    final answer = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Tokens.paper,
        title: const Text('For grown-ups'),
        content: TextField(
          controller: answer,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Year you were born',
            hintText: 'Example: 1985',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final year = int.tryParse(answer.text.trim());
              final age = year == null ? 0 : DateTime.now().year - year;
              if (age >= 18 && age <= 100) {
                Navigator.pop(c);
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ParentDashboardScreen()),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Tokens.leaf),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

final _skillsProvider = FutureProvider.family<List<SkillState>, String>(
  (ref, childId) {
    ref.watch(progressDataRevisionProvider);
    return ref.watch(progressRepositoryProvider).allSkills(childId);
  },
);

class _Vine extends StatelessWidget {
  const _Vine({required this.mastered});

  final int mastered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: [
          for (var i = 0; i < 26; i++)
            Icon(
              i < mastered ? Icons.eco_rounded : Icons.circle_outlined,
              size: 34,
              color: i < mastered ? Tokens.leaf : Tokens.paperDeep,
            ),
        ],
      ),
    );
  }
}
