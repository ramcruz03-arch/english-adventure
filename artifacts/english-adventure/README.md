# English Adventure — Flutter skeleton

A systematic-phonics reading and writing app for beginner readers aged 5–9.
This repository is the **vertical slice**: one game running end to end through
every architectural layer, so the remaining six games are a matter of filling
in a slot rather than inventing a structure.

Framework: **Flutter**. Default voice: **en-GB**, switchable to en-IN in settings.

---

## Run it

```bash
flutter pub get
flutter run                                # child app
dart run tools/validate_content.dart       # content gate (also run this in CI)
flutter test                               # mastery-algorithm tests
```

## Build an APK on GitHub

The repository includes a GitHub Actions workflow for producing an APK without
requiring an Android SDK in the development workspace:

1. Push this repository to GitHub.
2. Open the **Actions** tab and choose **Build English Adventure APK**.
3. Select **Run workflow** and confirm the branch.
4. When the run finishes, open it and download the `english-adventure-apk`
   artifact.
5. Extract `app-release.apk` and install it on the Android device.

The workflow runs the content validator, `flutter analyze`, and `flutter test`
before building. This APK uses the current debug signing configuration for
device testing; configure a private release keystore before publishing to
Google Play.

> Written without a Dart SDK to hand, so treat the first `flutter analyze` as
> part of setup — expect a few import or lint fixes, not structural ones.

---

## What is built

| Layer | Status |
|---|---|
| Design tokens + accessibility overrides (font, spacing, line height, reduce motion) | ✅ |
| Domain entities: Grapheme, Word, SkillState, Activity | ✅ |
| `applyOutcome` — EMA mastery + Leitner scheduling, pure and unit-tested | ✅ |
| `buildDailyPath` — one new sound per session, no new material after a hard day | ✅ |
| `selectDistractors` — b/d and p/q never co-occur before level 3 | ✅ |
| sqflite schema + ProgressRepository | ✅ |
| JSON content pack + asset loader | ✅ |
| Content validator (CI gate) | ✅ |
| **Game A — Letter Garden**, full support ladder + frustration watcher | ✅ |
| **Game B — Sound Detective**, 5 rounds, tiered distractors | ✅ |
| **Game C — Word Builder**, drag *and* tap-to-place, blend sweep | ✅ |
| Shared support ladder + frustration watcher (`presentation/shared/`) | ✅ |
| Session runner + Reward Room | ✅ |
| Home garden with vine progress | ✅ |
| **Game D — Trace & Write** | ✅ forgiving touch tracing, local sample persistence |
| **Game E — Read Sentence** | ✅ hear-and-read decodable word groups |
| **Game F — Mini Story** | ✅ two-page read-aloud story |
| **Game G — Spelling Picnic** | ✅ accessible tap-to-place spelling |
| **Parent dashboard** | ✅ gated progress summary and sound-by-sound practice view |
| Tamil UI, cloud sync | not started |

---

## Design direction

The guide is **Anil**, a three-striped Indian palm squirrel — chosen over the
default owl/fox because the child should recognise the animal from her own
courtyard.

The palette comes from a South Indian garden at mid-morning: warm oat paper,
bark-brown ink, leaf green for growth, marigold for reward, hibiscus for Anil's
scarf alone. Two of those are accessibility decisions wearing an aesthetic coat:
the oat background (`#F7EFE2`) avoids the glare and visual crowding that white
causes for readers with dyslexia-like difficulties, and bark brown replaces
black for the same reason.

**The signature element is the Sound Stone** — one letter, 168pt, resting on a
garden stone. Tapping it always replays the sound, so a child can never be stuck
for want of hearing it again.

**Progress is a vine, not a bar.** One leaf per mastered sound. No numbers, no
percentages, no streak. A child who disappears for a week returns to the same
vine rather than to a broken streak — the guilt mechanic that makes most
learning apps quietly punishing.

---

## Three rules the code enforces so no screen has to

1. **`Word.isDecodableWith(taught)`** — a word may only be shown when every
   grapheme in it has been taught. `tools/validate_content.dart` fails the build
   otherwise. This is why the app never asks a child to read something nobody
   taught her.
2. **The support ladder** (`letter_garden_controller.dart`) — miss once, get a
   hint; miss twice, get a demonstration; miss three times, the activity ends
   warmly and the difficulty drops. There is no fourth branch and no failure
   state anywhere in the codebase.
3. **Speed is never a difficulty signal.** `response_ms` is recorded for the
   parent dashboard and deliberately excluded from `applyOutcome`. Slow and
   correct is fully correct.

---

## The TTS trap

Give a text-to-speech engine the letter `b` and it says *"bee"* — teaching the
child exactly the wrong thing. Every grapheme therefore ships an explicit
`tts_fallback` (`"sss"`, `"mmm"`, `"ah"`) and the validator blocks any grapheme
that lacks one. `SpeechService.speakPhoneme` is the only sanctioned path to
child-facing sound; when recorded human audio arrives, implement that one
interface and no game screen changes.

---

## Deliberate departure from the plan

The plan recommended Drift. This skeleton uses plain **sqflite** instead: no
`build_runner`, no codegen step, faster on a modest laptop. Everything sits
behind `ProgressRepository`, so moving to Drift later is a data-layer change and
nothing above it moves.

---

## Placeholders to replace before any child sees this

- `emoji` fields in `words.json` → real illustrations, one obvious noun each,
  culturally readable in India (use *van*, not *vault*)
- Anil's 🐿️ circle → illustrated character in ~6 poses
- Bundled fonts: Andika (child), Lexend (parent), Baloo Thambi 2 (Tamil)
- `stroke_paths` exist for 8 letters — 44 more needed before Trace & Write ships

---

## Next piece

**Trace & Write** — `CustomPainter` plus the resample/coverage scorer from
§16.4 of the plan. Budget two weeks; it is the hardest thing in the app, and
the one most likely to feel like judgement if it is built carelessly.

After that the MVP needs only one mini story and the parent dashboard.

## Release

`release/` holds the full Play Store kit: signing and Gradle config, build
commands, every Play Console answer, privacy policy in English and Tamil, store
listing copy, and a pre-submission checklist. Read
`release/PLAY_STORE_RELEASE_KIT.md` first — it opens with what is still missing
before this should go in front of a child.

## Where the item selection lives

`SessionScreen` is the only class that turns an abstract `Activity` into
concrete items — which words go on the tiles, which letters go on the table.
Game screens receive finished sets and contain no selection logic at all. That
is deliberate: it keeps every pedagogical decision in one file that unit tests
can reach, and it means a new game is a screen, not a rethink.
