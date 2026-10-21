# AirCard17

An iOS Wallet card-art reskinner for compatible iOS 17 devices. Import an image, choose a Wallet card, and AirCard17 updates the card artwork while preserving a backup for one-tap restore.

This project is intended for personal device customization. It does not change card credentials, payment authorization, NFC data, or the underlying card account. It changes local Wallet artwork only.

## What it does

- Finds payment cards in the local Wallet pass store
- Imports artwork from Photos or Files
- Crops artwork to the Wallet card ratio automatically
- Updates all available card artwork variants (@2x, @3x, and PDF when present)
- Creates per-file backups before the first replacement
- Restores the original artwork
- Saves previews back to Files for reuse

The app retains the inherited diagnostic and access screen because iOS 17 devices differ in what sideloading method and entitlements they provide. The main workflow is Cards → tap a card → choose an image.

## Compatibility

The practical route depends on the exact device and iOS build:

- iOS 17.0 devices with TrollStore can use direct file access.
- Other supported iOS 17 builds use the DarkSword/Lara access path.
- Unsupported hardware, patched iOS builds, or ordinary App Store signing cannot write the Wallet card store.

This is not a guarantee for every iOS 17.x/device combination. Test the first replacement with a card you can restore and keep the original backup. If the app reports that access is unavailable, do not keep retrying the exploit; export the diagnostic log and check the device/build support first.

The separate iOS 18–26 Airlift release in this repository includes the newer card/passcode backend and a Wallpapers tab. Wallpaper flashing on iOS 18–26 is experimental; the upstream AirCard-iOS project documents Tendies wallpaper support primarily for iOS 27+, while iOS 18–26 is documented for Wallet skins and passcode themes.

## Install

1. Open the latest GitHub Actions run for this repository.
2. Download aircard17-unsigned.ipa for AltStore, SideStore, Sideloadly, or another signer.
3. Download aircard17-trollstore.tipa only when installing through TrollStore.
4. Install the package and open AirCard17.

The unsigned IPA is not signed by this repository. Sign or sideload it with your own Apple account or preferred installer.

## First use

1. Open AirCard17 and scan the Wallet cards.
2. If the app asks for access, use the Access/Exploit screen and follow the status shown for your install method.
3. Tap a payment card.
4. Choose an image from Photos or Files. The app centers/crops it to a card-shaped canvas and updates every detected artwork scale.
5. Force-close Wallet and reopen it. A reboot may be needed on some iOS builds.
6. Use Restore on the same card to return to the original artwork.

For a platinum-style look, start with a wide image containing the background, issuer mark, and any design text you want. Use artwork you are allowed to use; AirCard17 does not provide or endorse bank-branded artwork.

## Wallpapers: importing a Cowabunga .tendies file

A .tendies file is a PosterBoard wallpaper archive. It can contain the descriptors, metadata, images, and video/animation assets that iOS uses for a dynamic Lock Screen wallpaper. AirCard17 does not play the animation itself; PosterBoard and SpringBoard do that after the wallpaper has been installed.

Do not unzip the file. Keep the complete .tendies file together.

### Requirements

- Use the iOS 18–26 Airlift build for this feature.
- The phone must be unlocked.
- LocalDevVPN/loopback connectivity must be working.
- A valid pairing record must already be imported in the Pairing tab.
- Keep the phone connected and avoid locking it while flashing.
- Use a .tendies package made for the relevant iOS generation. A package made for a different PosterBoard layout may import but fail to appear or may be rejected.

### Steps

1. Download or export the wallpaper from Cowabunga as a .tendies file.
2. Save it in the Files app. If it is inside a ZIP, extract only until you can see the actual .tendies file.
3. Open AirCard17 and open the Wallpapers tab.
4. Tap Choose .tendies from Files.
5. Select the wallpaper file. Wait for the preview/type badge to appear in the gallery.
6. Select the wallpaper row. Leave Force PosterBoard Cache Refresh enabled for the first attempt.
7. Tap Flash 1 Wallpaper and wait for the log to finish.
8. AirCard17 will attempt a NeoSpring respring. The screen may go black briefly.
9. After the respring, open the native Lock Screen wallpaper picker: long-press the Lock Screen and tap Customize, or create a new wallpaper.
10. Look in the Collections/available wallpaper picker for the imported wallpaper and select it. Flashing installs the wallpaper into PosterBoard; it may not automatically make it the currently active Lock Screen.
11. If it does not appear, respring once more from the Wallpapers tab, then reboot before trying the same package again.
12. If the app reports a container or injection error, do not repeatedly flash the same package. Save the flash log and try a descriptor-format package from the same wallpaper source.

A .tendies file can be either a descriptor package or a container package. Descriptor packages are generally safer for installing several wallpapers because their identifiers can be randomized to avoid collisions. Container packages preserve the original PosterBoard container structure and are more sensitive to iOS-version differences.

### Removing or reverting

AirCard17 can remove an imported package from its own local list, but that does not necessarily remove files already injected into PosterBoard. To clean up a wallpaper that was flashed successfully, use the native Lock Screen wallpaper picker to stop using it, then reboot if PosterBoard continues showing stale entries. Keep a normal iOS backup before experimenting with container-format packages.

### iOS 17 legacy wallpaper support

The iOS 17 legacy build currently has no Tendies/PosterBoard engine. Its exploit path was built around reading and overwriting Wallet artwork files, not recursively staging PosterBoard descriptors and triggering the newer PosterBoard refresh flow.

Adding wallpaper support to that build is technically conceivable, but it would be a separate feature rather than a small UI change. It would require:

- a .tendies archive parser and descriptor/container classifier;
- iOS 17-specific PosterBoard paths and identifiers;
- recursive directory injection and cache/protection handling;
- a safe respring/reload path;
- extensive testing on each iOS 17 device/build.

I am not treating that as completed or safe yet. The first version should remain manual: install one wallpaper, verify it, and then choose it in the native Lock Screen picker. An automatic wallpaper-changing daemon would add complexity and could keep the app or helper alive unnecessarily.

### Battery and stability

Installing or changing a wallpaper occasionally should have negligible battery impact after the flash is complete. iOS owns the actual animation and only renders it when appropriate, such as on the Lock Screen. Battery use can be higher while an animated wallpaper is visible, especially with video-heavy assets or frequent Lock Screen wakeups.

The larger risk is stability, not idle battery: repeatedly injecting large packages, forcing resprings, or using a package from the wrong iOS generation can leave PosterBoard caches inconsistent. Avoid rapid retries, keep the phone unlocked during a flash, and reboot if SpringBoard or PosterBoard behaves abnormally.

## Build from source

The repository builds on GitHub Actions using a macOS runner, so a local Mac is not required for the standard unsigned IPA workflow. The workflow runs on pushes to main and can also be started manually from the Actions tab.

~~~bash
xcodebuild \
  -project AirCard17.xcodeproj \
  -scheme AirCard17 \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""
~~~

The bundled GitHub Actions workflow also packages the unsigned IPA and the TrollStore TIPA, then uploads both as workflow artifacts.

## Credits and license

AirCard17 is an independent derivative focused on Wallet card artwork. The access and filesystem portions are derived from CardioDS, DarkSword, XPF, libgrabkernel2, and Lara. Their notices and the AGPL-3.0 license are retained in this repository.

AirCard17 is not affiliated with Apple, American Express, or any card issuer.
