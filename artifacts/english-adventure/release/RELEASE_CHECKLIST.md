# Pre-submission checklist

Tick every line. Anything unticked is a reason to wait a week.

## Build
- [x] `dart run tools/validate_content.dart` passes with zero errors
- [x] `flutter analyze` clean
- [x] `flutter test` green
- [ ] Release APK installed on a real 2 GB Android phone and played through
- [ ] `aapt dump permissions` prints nothing
- [ ] AAB under 60 MB
- [ ] Cold start under 2.5s on the low-end test device
- [ ] Airplane mode: full session completes with no error
- [ ] Kill and reopen mid-session: progress is intact
- [ ] Every one of the 15 sounds heard aloud and confirmed correct by ear
- [ ] TTS still works in the *release* build (obfuscation breaks it silently)

## Content
- [ ] No emoji placeholders remain anywhere a child can see
- [ ] Every picture shows one unambiguous noun, readable in India
- [ ] No word appears before all its sounds are taught (validator proves this)
- [ ] No screen contains the words wrong, failed, slow, or any comparison
- [ ] No timer, countdown, life, streak or leaderboard anywhere

## Accessibility
- [ ] Every tap target measured at 60dp or more
- [ ] Contrast checked at 7:1 for text
- [ ] Font size, spacing and reduce-motion settings all take effect
- [ ] Mute works everywhere, including mid-narration
- [ ] Nothing flashes faster than 3Hz

## Safety
- [ ] Parent gate cannot be passed by a seven-year-old (test this on one)
- [ ] No external link reachable from any child screen
- [ ] Delete-all-data works offline and actually empties the database
- [ ] `flutter pub deps` shows no ads, attribution or tracking SDK

## Console
- [ ] Privacy policy live at a public URL, dated
- [ ] Data safety form matches what the build actually does
- [ ] Target audience: children only
- [ ] Content rating questionnaire submitted
- [ ] Screenshots show only features that exist
- [ ] Contact email monitored

## The one that matters
- [ ] At least five children aged 5–9 have used it, observed, and none of them
      looked embarrassed at any point
