# Changelog

Each store release, with the store's What's New and the date it went live on each store.
Every release has a matching tag and a [GitHub Release](https://github.com/hyya-dev/hYYa-Digital-Footprint-Check/releases).
Website: [hyya.com/hyya-digital-footprint-check.html](https://hyya.com/hyya-digital-footprint-check.html)

## 1.1.0

What's New (Google Play):
> • A calmer new look, easier on the eyes.
> • Simpler results: what you can fix comes first, with what each fix is worth.
> • Check-up starts with five essential steps, and any check can be run again from your score.
> • A wider home screen widget, and easier to use with TalkBack and larger text.
> This release contains general bug fixes and stability improvements.

What's in it (Android):
- A new look: a warm charcoal page, flat slate cards, a muted gold accent, and the detective in a soft spotlight.
  A card that is worth a look carries a coral edge; a fix carries a green one.
- Simple by default: Footprint opens on the things you can fix, each with its points, and the full list is one tap
  away. A finding shows the headline, what's on your device and the fix; a finding worth a look keeps "How
  serious" in view, and the rest folds under "More about this".
- Check-up opens on five essentials, with the other areas one tap away. It counts toward your score once the five
  are done; if you had already finished every area that counted before, you keep that credit.
- Every finished check has "Check again" on the Score page, and (versionCode 30) the Score page says when it was
  last checked and offers "Check everything again".
- Sensitive apps checks every kind by default, with Select all / Clear all.
- Clear history asks first and says when it's done.
- "Add the widget" places the wide widget; the small one is roomier.
- Clearer TalkBack labels and states, and a lighter faint grey that reads at 4.5:1.

| Store | Version | Live | Source |
|---|---|---|---|
| Google Play | 1.1.0 (versionCode 29) | 2026-11-16 | tag `v1.1.0-android29` |
| Google Play | 1.1.0 (versionCode 30): the Score page says when it was last checked and offers "Check everything again" | 2026-11-16 | tag `v1.1.0-android30` |

## 1.0.8

What's New (Google Play):
> • Add the widget to your home screen in one tap, from the Score page.
> This release contains general bug fixes and stability improvements.

What's in it (Android):
- An "add the widget" card on the Score page. One tap opens your launcher's own Add sheet. It only appears
  where that works and no score widget is placed yet, and "Not now" hides it for good.
- The widget picker shows a sample score instead of an empty widget, and says why to add it.
- The app checks it is running as itself. A store build won't open on a rooted device, with a hooking tool
  (Frida, Xposed/LSPosed, Substrate) loaded into it, with a debugger attached, or as a re-signed copy. The
  screen names what it found and gives the steps to fix it. USB debugging on its own never blocks.
- The F-Droid edition only warns about root, once per version, then carries on. Hooking tools and debuggers
  still block there. It skips the signature check, since F-Droid signs with its own key.
- The Play edition's in-app review library now uses a current androidx.fragment (1.8.9).

| Store | Version | Live | Source |
|---|---|---|---|
| Google Play | 1.0.8 (versionCode 28) | 2026-11-13 | tag `v1.0.8-android28` |

## 1.0.7

What's New (Google Play):
> This release contains general bug fixes and stability improvements.

What's in it:
- Android only: after a scan that raised your score, or once you've come back on another day, the app may
  ask for a rating with Google Play's standard in-app prompt. It asks at most once per version and never on
  the first scan. The F-Droid edition leaves this out.

| Store | Version | Live | Source |
|---|---|---|---|
| Google Play | 1.0.7 (versionCode 27) | 2026-11-09 | tag `v1.0.7-android27` |

## 1.0.6

What's New (App Store, Mac App Store and Google Play):
> This release contains general bug fixes and stability improvements.

What's in it:
- Your score counts only what any app can read without asking. What apps see once you allow them is shown
  as advice, and details you need, such as your languages and keyboards, are shown just so you know.
- Keep it: I trust this. Keep a finding or a Tracker app you trust (on Android, a special access you trust):
  it stays listed but no longer counts, and you can undo it.
- The Tracker page dates the 7-day window by who apps talked to, and names the older date separately when
  their use of your data goes back further.
- On dark pages the detective appears in his night scene.
- Calmer sticky-note colours, with text colours measured for clear reading on each one.
- The "Report a Security Issue" e-mail uses the app's new name.
- Android only: a medium-size home screen widget, and the app's full name everywhere except under the
  home screen icon.

| Store | Version | Live | Source |
|---|---|---|---|
| Google Play | 1.0.6 (versionCode 26) | 2026-11-08 | tag `v1.0.6-android26` |
| Mac App Store | 1.0.6 (build 40) | 2026-11-08 | tag `v1.0.6-build40` |
| App Store (iPhone and iPad) | 1.0.6 (build 40) | 2026-11-09 | tag `v1.0.6-build40` |

## 1.0.5

What's New (App Store and Google Play):
> This release contains general bug fixes and stability improvements.

What's in it:
- The app is now called hYYa Digital Footprint Check, with a new detective mascot and icon.
- Every section is written on a detective's sticky note.
- Settings cards are fully tappable.

| Store | Version | Live | Source |
|---|---|---|---|
| Google Play | 1.0.5 (versionCode 21) | 2026-11-06 | tag `v1.0.5-android21` |
| App Store (iPhone and iPad) | 1.0.5 (build 35) | 2026-11-06 | tag `v1.0.5-build35` |

The Mac went straight from 1.0.1 to 1.0.6.

## Earlier versions

1.0.0 to 1.0.4 came before this changelog. Their tags start at `v1.0.2`.
