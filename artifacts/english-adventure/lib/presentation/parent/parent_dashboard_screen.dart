import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/entities/skill_state.dart';

class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childId = ref.watch(activeChildProvider);
    final prefs = ref.watch(readingPrefsProvider);
    final tamil = prefs.language == 'ta';
    final parentFace = tamil ? Tokens.displayFace : Tokens.uiFace;
    final baseTheme = Theme.of(context);
    final dashboardTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: parentFace),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: parentFace),
    );
    final skills = ref.watch(_dashboardSkillsProvider(childId));
    final accuracy = ref.watch(_accuracyProvider(childId));

    return Theme(
      data: dashboardTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tamil ? 'பெற்றோர் பகுதி' : 'Grown-up view'),
          backgroundColor: Tokens.paper,
        ),
        body: skills.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
              child: Text(tamil
                  ? 'முன்னேற்றத்தை இப்போது ஏற்ற முடியவில்லை.'
                  : 'We could not load progress yet. $error')),
          data: (items) {
            final graphemes =
                items.where((s) => s.skillType == 'grapheme').toList();
            final mastered =
                graphemes.where((s) => s.status == SkillStatus.mastered).length;
            final learning =
                graphemes.where((s) => s.status == SkillStatus.learning).length;
            return ListView(
              padding: const EdgeInsets.all(Tokens.gutter),
              children: [
                Text(
                    tamil
                        ? 'இந்தத் தோட்டத்தின் முன்னேற்றம்'
                        : 'Progress for this garden',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                    tamil
                        ? 'மதிப்பெண்கள் அல்லது ஒப்பீடுகள் இல்லாத அமைதியான சுருக்கம்.'
                        : 'A calm summary of practice, without scores or comparisons.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                        child: _Metric(
                            label: tamil ? 'கற்ற ஒலிகள்' : 'Sounds grown',
                            value: '$mastered')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _Metric(
                            label: tamil ? 'பயிற்சியில்' : 'In practice',
                            value: '$learning')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Metric(
                        label: tamil ? 'கடைசி பயிற்சி' : 'Last session',
                        value:
                            '${((accuracy.valueOrNull ?? 1.0) * 100).round()}%',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(tamil ? 'ஒலித் தோட்டம்' : 'Sound garden',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ...graphemes.map((skill) => _SkillRow(skill: skill)),
                if (graphemes.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(tamil
                          ? 'பயிற்சிக்குப் பிறகு முதல் சாகசம் இங்கே தோன்றும்.'
                          : 'The first adventure will appear here after practice.'),
                    ),
                  ),
                const SizedBox(height: 28),
                const _AccessibilityNote(),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, _) {
                    final controller = ref.read(readingPrefsProvider.notifier);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                tamil ? 'வாசிப்பு உதவிகள்' : 'Reading supports',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            _SupportSlider(
                              label: 'Text size',
                              value: prefs.textScale,
                              min: 0.9,
                              max: 1.4,
                              divisions: 5,
                              onChanged: (value) {
                                controller.setTextScale(value);
                              },
                            ),
                            _SupportSlider(
                              label: 'Letter spacing',
                              value: prefs.letterSpacing,
                              min: 0,
                              max: 0.12,
                              divisions: 3,
                              onChanged: (value) {
                                controller.setLetterSpacing(value);
                              },
                            ),
                            _SupportSlider(
                              label: 'Line spacing',
                              value: prefs.lineHeight,
                              min: 1.3,
                              max: 2.0,
                              divisions: 7,
                              onChanged: (value) {
                                controller.setLineHeight(value);
                              },
                            ),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Reduce motion'),
                              subtitle: const Text(
                                  'Use calmer transitions and animations'),
                              value: prefs.reduceMotion,
                              onChanged: (value) {
                                controller.setReduceMotion(value);
                              },
                            ),
                            const Divider(),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  tamil ? 'பெற்றோர் மொழி' : 'Parent language'),
                              subtitle: Text(tamil ? 'தமிழ்' : 'English'),
                              trailing: SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(value: 'en', label: Text('EN')),
                                  ButtonSegment(
                                      value: 'ta', label: Text('தமிழ்')),
                                ],
                                selected: {prefs.language},
                                onSelectionChanged: (values) {
                                  controller.setLanguage(values.first);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                _DeleteAllDataCard(
                  tamil: tamil,
                  onDeleted: () async {
                    await ref.read(progressRepositoryProvider).deleteAllData();
                    ref.read(activeChildProvider.notifier).state = 'child_1';
                    ref.read(progressDataRevisionProvider.notifier).state++;
                    ref.invalidate(unfinishedSessionProvider(childId));
                    if (context.mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

final _dashboardSkillsProvider =
    FutureProvider.family<List<SkillState>, String>(
  (ref, childId) {
    ref.watch(progressDataRevisionProvider);
    return ref.watch(progressRepositoryProvider).allSkills(childId);
  },
);

final _accuracyProvider = FutureProvider.family<double, String>(
  (ref, childId) {
    ref.watch(progressDataRevisionProvider);
    return ref.watch(progressRepositoryProvider).lastSessionAccuracy(childId);
  },
);

class _DeleteAllDataCard extends StatelessWidget {
  const _DeleteAllDataCard({
    required this.tamil,
    required this.onDeleted,
  });

  final bool tamil;
  final Future<void> Function() onDeleted;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Tokens.paper,
        title: Text(tamil ? 'அனைத்து தரவையும் நீக்கவா?' : 'Delete all data?'),
        content: Text(
          tamil
              ? 'இந்த சாதனத்தில் உள்ள அனைத்து குழந்தை சுயவிவரங்கள், பயிற்சி மற்றும் முன்னேற்றம் நிரந்தரமாக நீக்கப்படும்.'
              : 'This permanently removes every child profile, practice record, '
                  'reward, handwriting trace, and queued record from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tamil ? 'ரத்து செய்' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text(tamil ? 'அனைத்தையும் நீக்கு' : 'Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await onDeleted();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tamil
              ? 'தரவுகளை நீக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.'
              : 'We could not delete the data. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tamil ? 'தனியுரிமை' : 'Privacy',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                tamil
                    ? 'இந்த சாதனத்தில் சேமிக்கப்பட்ட குழந்தைத் தரவை எப்போது வேண்டுமானாலும் நீக்கலாம்.'
                    : 'Remove everything stored on this device whenever you need to.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_forever_outlined),
                label:
                    Text(tamil ? 'அனைத்து தரவையும் நீக்கு' : 'Delete all data'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        color: Tokens.leafLight,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.skill});
  final SkillState skill;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(
            skill.status == SkillStatus.mastered
                ? Icons.eco_rounded
                : Icons.spa_outlined,
            color: skill.status == SkillStatus.mastered
                ? Tokens.leaf
                : Tokens.inkSoft,
          ),
          title: Text(skill.skillId.replaceFirst('g:', '').toUpperCase()),
          subtitle: Text(
              '${skill.exposures} practices · ${skill.correctCount} comfortable'),
          trailing: Text(skill.status.name),
        ),
      );
}

class _AccessibilityNote extends StatelessWidget {
  const _AccessibilityNote();

  @override
  Widget build(BuildContext context) => Card(
        color: Tokens.paperDeep,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Reading supports such as larger text, wider letters, line spacing, '
            'and reduced motion are available in the app settings.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
}

class _SupportSlider extends StatelessWidget {
  const _SupportSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final void Function(double) onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: value.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ],
      );
}
