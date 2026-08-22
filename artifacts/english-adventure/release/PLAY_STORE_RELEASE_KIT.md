# Play Store release kit — English Adventure

Everything needed to sign, build, declare and submit. Follow it top to bottom.

---

## First, the honest part

**I cannot hand you a finished `.aab` from here.** Producing one needs the
Flutter SDK and Android toolchain running on your machine against your own
signing key — a key that must never leave your hands, or you lose the ability to
update the app under this listing forever.

More to the point: **this app is not ready to put in front of children yet.**
Play would very likely accept it. That is not the same standard. What is missing:

| Gap | Why it blocks a real launch |
|---|---|
| Games D–G unbuilt (Trace, Sentence, Story, Spelling) | The listing promises writing and stories. Shipping without them is a false claim, and Play removes apps for that. |
| No illustrations — emoji placeholders | Emoji are ambiguous. 🧍 is not obviously "man". A child guessing at the picture is being tested on the wrong thing. |
| No parent dashboard | The single feature a paying parent evaluates. |
| Device TTS only | TTS mispronounces phonemes on some Android builds. Every one of the 15 sounds must be heard on real low-end devices before a child does. |
| Zero testing with children | You would be shipping a literacy intervention that no learner has tried. |

**Suggested path:** finish Trace & Write and one story, replace the emoji, build
the dashboard, then run the internal testing track with five children you know.
That is roughly six weeks of evenings. Everything below is ready and waiting for
that moment.

---

## 1. Signing key — do this once, carefully

```bash
keytool -genkey -v \
  -keystore ~/english-adventure-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Then `cp android/key.properties.example android/key.properties` and fill it in.

**Back the `.jks` up to two places that are not your laptop.** Losing it means
you can never update this app again — you would have to publish a new listing
and abandon every install and review. Both `key.properties` and `*.jks` are
already in `.gitignore`.

Enrol in **Play App Signing** when you first upload (it is the default). Google
then holds the app signing key and yours is only the upload key, which *can* be
reset if lost.

---

## 2. Gradle release config

Add to `android/app/build.gradle` (Groovy). If your Flutter version generated
`build.gradle.kts`, the same blocks apply with Kotlin syntax.

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    namespace "com.yourname.englishadventure"   // pick once; permanent
    compileSdk 35

    defaultConfig {
        applicationId "com.yourname.englishadventure"
        minSdk 23        // Android 6.0 - covers the low-end phones you are targeting
        targetSdk 35     // Play requires current-1 or newer
        versionCode 1
        versionName "0.1.0"
    }

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
                          'proguard-rules.pro'
        }
    }
}
```

`applicationId` is permanent. Choose it now and do not change it.

---

## 3. Build

```bash
flutter clean
flutter pub get
dart run tools/validate_content.dart     # content gate - must pass
flutter analyze
flutter test
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Verify before uploading:

```bash
# Should print NOTHING. A children's app requesting permissions invites scrutiny.
aapt dump permissions build/app/outputs/bundle/release/app-release.aab

# Size check - the target phone has little storage and less data allowance
ls -lh build/app/outputs/bundle/release/app-release.aab
```

Test the actual release artifact, not just a debug build:

```bash
flutter build apk --release --split-per-abi
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Release builds obfuscate and shrink; things that work in debug can break here.
Check that TTS still speaks — that is the usual casualty.

---

## 4. Console setup, in order

1. Create the app: name, default language **English (India)**, app not game, free.
2. **App content** — enter every answer from `data-safety-answers.md`.
3. Upload the privacy policy URL. It must be live before you submit.
4. **Store listing** — copy from `store-listing-en.md`; add Tamil from
   `store-listing-ta.md` as a second locale.
5. Upload graphics (specs in the listing file).
6. **Internal testing** track first. Up to 100 testers by email, available in
   minutes, no review wait. Your five families go here.
7. Then **closed testing**. Play now requires a sustained closed test before
   production for new personal developer accounts — currently 12 testers running
   for 14 continuous days. Check the current rule in Console; it has changed
   twice recently.
8. Then production, with a **staged rollout at 20%**.

---

## 5. What review will look at, for this app specifically

- **Ads declaration vs reality.** You declare none; make sure no dependency
  pulls in an ads or attribution SDK. Check with `flutter pub deps`.
- **Families Policy.** A child must not reach any external link. Your parent
  gate is the control. Make it a real gate — a birth year, not "tap twice".
- **Screenshots must match the app.** Do not show Trace & Write until it exists.
- **The description must not overclaim.** No "cures dyslexia", no "guaranteed
  results", no medical claims. Say what the app does.
- **Target audience.** Ticking a children bracket is irreversible in effect —
  it binds you to Families Policy for the life of the listing.

---

## 6. iOS, when you get there

Needs a Mac, an Apple Developer account at US$99/year, and the **Kids Category**,
which is stricter than Play: a parental gate is mandatory before any external
link or purchase, and third-party analytics are prohibited without verifiable
parental consent. The app as designed already meets both.

---

## 7. Version discipline

`versionName` is what parents see; `versionCode` must increase every upload.

| Version | Contains |
|---|---|
| 0.1.0 | internal only — three games, no dashboard |
| 0.5.0 | closed testing — all seven games, real art, dashboard |
| 1.0.0 | production — after the pilot with real children |

Never ship a build to production that no child has used.
