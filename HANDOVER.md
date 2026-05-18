# Jumpcut Handover

This handover describes the local Jumpcut fork work completed for the extended
clipping workflow, the opt-in preference that now gates those additions, the
installed app update, and the GitHub release artifact.

## Scope Completed

- Added saving/export actions for clippings.
- Increased the optional clipping history capacity from 99 to 500.
- Added favourites for clippings.
- Added bold, italic, and color labels for clippings.
- Added a Hotkey preferences checkbox so the extra fork-only features are
  opt-in.
- Updated About Jumpcut and the README with usage notes.
- Installed the locally built app over `/Applications/Jumpcut.app` without
  changing the existing clipping store.
- Published the implementation to `origin/master`.
- Prepared a GitHub release asset for tag `v0.84-nyimbi.1`.

Feature commit before this handover:

```text
ffe31de Keep Jumpcut minimal until extended clipping tools are enabled
```

## New User Capabilities

### Extended Features Opt-In

The fork-only features are off by default for ordinary installs. They are
enabled with:

```text
Preferences > Hotkey > Enable extended clipping actions and 500-item history
```

When the checkbox is off:

- The visible menus stay close to upstream Jumpcut.
- Save/export actions are not shown.
- Favourites, bold, italic, color, and `[F]` markers are not shown.
- The effective clipping history limit is capped at 99.

When the checkbox is on:

- History can retain up to 500 clippings.
- Individual clippings can be added to or removed from Favourites.
- Favourite clippings are marked with `[F]`.
- Individual clippings can be made bold, made italic, or assigned a palette
  color.
- Bold, italic, and color labels are visible in the main clipping menu, the
  alternate menu, and the Favourites submenu.
- A dedicated Favourites submenu is available.
- Selected clippings can be saved to a text file.
- All clippings can be saved to one text file.
- All clippings can be saved as separate text files.

Existing users who already had `rememberNum` above 99 are migrated with
`extendedFeaturesEnabled` set to true. This avoids silently truncating an
existing larger clipping history after upgrade.

### Saving Clippings

Extended mode adds these menu actions:

- `Save item to file...` from an individual clipping's alternate submenu.
- `Save All to File...` from the fixed menu area.
- `Save All as Files...` from the fixed menu area.

Filenames for individual exports are derived from the clipping text, sanitized,
and prefixed with a one-based index such as `001-example.txt`.

### Favourites

To favourite a clipping after enabling extended mode:

1. Open Jumpcut's alternate clipping menu.
2. Hover the clipping.
3. Choose `Add to Favourites`.

The alternate menu behavior depends on existing Jumpcut preferences, for
example right-click or Shift-click on the menu bar icon.

### Visual Labels

To make a clipping easier to find after enabling extended mode:

1. Open Jumpcut's alternate clipping menu.
2. Hover the clipping.
3. Choose `Make Bold`, `Make Italic`, or a color from `Color`.

These labels are persisted with the clipping and move with it. They are visible
where the clipping is listed, including the primary menu.

## Code Changes

### `Jumpcut/Jumpcut/Settings.swift`

- Added `SettingsPath.extendedFeaturesEnabled`.
- Registered the default value as `false`.
- Added helper methods:
  - `Settings.extendedFeaturesEnabled()`
  - `Settings.maximumRememberNum()`
  - `Settings.defaultRememberNum()`
  - `Settings.effectiveRememberNum()`
- Added migration logic that enables extended features if an existing
  `rememberNum` value is already above 99.
- Widened stepper value display space so `500` renders cleanly.

### `Jumpcut/Jumpcut/Preferences/HotkeyPreferenceViewController.swift`

- Added the opt-in checkbox in the Hotkey pane.
- Increased the pane height to fit the new checkbox.
- When the checkbox is turned off, `rememberNum` is clamped back to 99 if it was
  above the standard limit.

### `Jumpcut/Jumpcut/Preferences/GeneralPreferenceViewController.swift`

- Made the Remembering stepper maximum dynamic:
  - 99 when extended mode is off.
  - 500 when extended mode is on.

### `Jumpcut/Jumpcut/Clippings.swift`

- Added optional `Favorite`, `Bold`, `Italic`, and `Color` persistence to
  `JCListItem`.
- Added `PositionedClipping`.
- Added `Clipping.isFavorite`, `Clipping.isBold`, `Clipping.isItalic`, and
  `Clipping.labelColor`.
- Added `ClippingLabelColor` for the fixed color palette.
- Added stack/store APIs:
  - `syncSettings()`
  - `allItems()`
  - `favoriteItems()`
  - `toggleFavorite(position:)`
  - `toggleBold(position:)`
  - `toggleItalic(position:)`
  - `setLabelColor(position:color:)`
- Changed clipping history sizing to use `Settings.effectiveRememberNum()`.
- Preserved backwards compatibility with older saved plist files by treating
  missing `Favorite` values as `false`.
- Fixed bounds checks that could incorrectly allow `position == count`.
- Fixed persisted `rememberNum` to write the effective remember limit rather
  than the display count.

### `Jumpcut/Jumpcut/MenuManager.swift`

- Added stable clipping positions through `NSMenuItem.representedObject`.
- Added styled menu titles when extended mode is enabled.
- Added `[F]` title markers when extended mode is enabled.
- Added Favourites submenu when extended mode is enabled.
- Added bold, italic, and color controls to the alternate clipping menu.
- Added save/export menu items when extended mode is enabled.
- Kept the standard Clear All, About, Preferences, and Quit actions available in
  both modes.

### `Jumpcut/Jumpcut/Interactions.swift`

- Added handlers for:
  - `menuToggleFavorite(sender:)`
  - `menuToggleBold(sender:)`
  - `menuToggleItalic(sender:)`
  - `menuSetLabelColor(sender:)`
  - `menuSaveItemToFile(sender:)`
  - `saveAllToFile(sender:)`
  - `saveAllAsFiles(sender:)`
- Added save panel/open panel handling for clipping exports.
- Added sanitized default filename generation and collision-safe output URLs.
- Added runtime guards so extended actions no-op if invoked while extended mode
  is disabled.
- Updated menu index extraction to prefer `representedObject` so submenu actions
  target the correct clipping.

### `Jumpcut/Jumpcut/AppDelegate.swift`

- Calls `stack.syncSettings()` when user defaults change so menu and clipping
  history limits respond to preference changes.

### `Jumpcut/JumpcutTests/JumpcutTests.swift`

- Replaced template tests with focused clipping behavior tests.
- Added coverage for:
  - 500 clipping retention when extended mode is enabled.
  - 99 clipping cap when extended mode is disabled.
  - trimming on remember-limit changes.
  - favourite toggling and favourites moving with their clipping.
  - bold, italic, and color labels moving with their clipping.
- Tests preserve and restore relevant user defaults.

### `Jumpcut/Jumpcut/Credits.html`

- Added About-window instructions for enabling extended mode and adding
  Favourites.

### `README.md`

- Documented the fork-only capabilities.
- Documented that they are opt-in through the Hotkey preferences pane.
- Documented bold, italic, and color labels.
- Added the requested note that the changes were made for personal use, sent as
  a PR, are probably not useful to others, and bend Jumpcut's minimalism.

## Installed App Notes

The installed app was replaced at:

```text
/Applications/Jumpcut.app
```

The existing clipping store was preserved at:

```text
~/Library/Application Support/Jumpcut/JCEngine.save
```

The clipping store SHA-256 stayed unchanged during the final install:

```text
472cce26061941f83c2262f4a4a4640a5e128d5008d1333a8b19b23ea43a5b07
```

Final install backup:

```text
/private/tmp/jumpcut-backup-20260518-014231
```

The installed app was ad-hoc signed after installation because the local machine
does not have a Mac Development signing identity available. `open
/Applications/Jumpcut.app` returned success after signing.

## Verification Performed

```text
git diff --check
```

Passed.

```text
xcodebuild test -project Jumpcut/Jumpcut.xcodeproj -scheme Jumpcut -destination 'platform=macOS' -derivedDataPath ./DerivedData CODE_SIGNING_ALLOWED=NO MACOSX_DEPLOYMENT_TARGET=10.13
```

Passed.

```text
xcodebuild build -project Jumpcut/Jumpcut.xcodeproj -scheme Jumpcut -configuration Release -destination 'platform=macOS' -derivedDataPath ./DerivedData CODE_SIGNING_ALLOWED=NO MACOSX_DEPLOYMENT_TARGET=10.13
```

Passed.

```text
codesign --verify --deep --strict --verbose=2 /Applications/Jumpcut.app
```

Passed after applying the local ad-hoc signature.

## Release Artifact

Latest release tag:

```text
v0.84-nyimbi.2
```

Release asset:

```text
Jumpcut-0.84-nyimbi.2-macOS.zip
```

Local release asset path:

```text
/private/tmp/jumpcut-release-v0.84-nyimbi.2/Jumpcut-0.84-nyimbi.2-macOS.zip
```

Asset SHA-256:

```text
a73e2da5f316c5733e79cfc2ec2498fa0ee5bae9028f11b48c11067c1a8abb4d
```

## Known Caveats

- The release app is ad-hoc signed, not signed with an Apple Developer
  certificate.
- Plain local Xcode builds without overrides are blocked by existing local
  signing/deployment-target constraints. The verified commands use
  `CODE_SIGNING_ALLOWED=NO` and `MACOSX_DEPLOYMENT_TARGET=10.13`.
- The release asset is an app zip for macOS, not a notarized installer package.
- Existing users with `rememberNum > 99` are intentionally migrated into
  extended mode to preserve their clipping history.

## Future Maintenance Notes

- Keep new fork-only clipping actions behind `Settings.extendedFeaturesEnabled()`
  unless the behavior is intentionally upstream-minimal.
- Preserve the optional `Favorite`, `Bold`, `Italic`, and `Color` fields as
  optional so older clipping save files continue to decode.
- If a signed public distribution is needed, rebuild with a valid Apple
  Developer identity and notarize before uploading a replacement release asset.
