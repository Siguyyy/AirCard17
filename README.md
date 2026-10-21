# AirCard17

An iOS Wallet card-art reskinner for compatible iOS 17 devices. Import an image, choose a Wallet card, and AirCard17 updates the card artwork while preserving a backup for one-tap restore.

This project is intended for personal device customization. It does not change card credentials, payment authorization, NFC data, or the underlying card account. It changes local Wallet artwork only.

## What it does

- Finds payment cards in the local Wallet pass store
- Imports artwork from Photos or Files
- Crops artwork to the Wallet card ratio automatically
- Updates all available card artwork variants (`@2x`, `@3x`, and PDF when present)
- Creates per-file backups before the first replacement
- Restores the original artwork
- Saves previews back to Files for reuse

The app retains the inherited diagnostic and access screen because iOS 17 devices differ in what sideloading method and entitlements they provide. The main workflow is Cards → tap a card → choose an image.

<p align="center">
  <a href="https://github.com/Siguyyy/AirCard17/releases/download/aircard17-ios17-latest/aircard17-ios17-wallpapers-experimental.ipa"><img src="https://img.shields.io/badge/Download-iOS%2017%20Experimental%20IPA-2ea44f?style=for-the-badge&logo=apple" alt="Download iOS 17 experimental IPA"></a>
  <a href="https://github.com/Siguyyy/AirCard17/releases/download/stable-latest/aircard17-unsigned.ipa"><img src="https://img.shields.io/badge/Download-Stable%20IPA-24292f?style=for-the-badge&logo=apple" alt="Download stable IPA"></a>
</p>

The buttons above download the IPA directly from the rolling GitHub Releases entries. GitHub may show a warning before the download; keep the file extension as `.ipa` and install it with your sideloader.

## Compatibility

The practical route depends on the exact device and iOS build:

- iOS 17.0 devices with TrollStore can use direct file access.
- Other supported iOS 17 builds use the DarkSword/Lara access path.
- Unsupported hardware, patched iOS builds, or ordinary App Store signing cannot write the Wallet card store.

This is not a guarantee for every iOS 17.x/device combination. Test the first replacement with a card you can restore and keep the original backup. If the app reports that access is unavailable, do not keep retrying the exploit; export the diagnostic log and check the device/build support first.

## Install

1. Open the latest GitHub Actions run for this repository.
2. Download `aircard17-unsigned.ipa` for AltStore, SideStore, Sideloadly, or another signer.
3. Download `aircard17-trollstore.tipa` only when installing through TrollStore.
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

## Experimental iOS 17 wallpaper build

The `experimental-ios17-wallpapers` branch contains a separate test build that adapts the legacy `.Trash` PosterBoard method used by Pocket Poster. It is not merged into the stable iOS 17 release.

To test it:

1. Download `aircard17-ios17-wallpapers-experimental.ipa` from the successful Actions run on the experimental branch and unzip the downloaded GitHub artifact once to obtain the IPA.
2. Install the IPA with your normal sideloader.
3. Open AirCard17 → **Wallpapers** and tap **Detect PosterBoard Automatically**. The app will first attempt to prepare its existing iOS 17 filesystem access, then scan for the PosterBoard container itself.
4. If automatic detection fails, connect the iPhone to a computer and use Nugget's **Settings → Pocket Poster Helper** to obtain the PosterBoard app hash/UUID. Paste the value into AirCard17 and tap **Save Hash**. Pocket Poster is not required for the automatic path.
5. Close the native wallpaper picker/PosterBoard from the app switcher before applying. Import one complete `.tendies` file and tap **Apply Wallpapers**.
6. Confirm the log says `PosterBoard Collections database updated (...)`. If it instead says the database was not reachable, stop there—the descriptors were copied but the wallpaper was not registered in Collections.
7. Reboot the iPhone manually after the app reports success.
8. Long-press the Lock Screen → **Customize** or **+**, then select the imported wallpaper from the native wallpaper picker under Collections.

The experimental build now randomizes the descriptor folder UUID and registers each imported descriptor in `PBFPosterExtensionDataStoreSQLiteDatabase.sqlite3`, matching the registration approach used by Nugget. This is the part the earlier build was missing. Keep at least 2 GB free on the phone while testing; PosterBoard and SQLite can fail when storage is nearly full.

This build uses a filesystem symlink/trash operation. If it fails, stop retrying and switch back to the stable IPA. Switching applications does not automatically remove any descriptors already injected into PosterBoard; use Pocket Poster/Nugget's PosterBoard reset/collections reset workflow if the native wallpaper picker becomes inconsistent.

## Build from source

The repository builds on GitHub Actions using a macOS runner, so a local Mac is not required for the standard unsigned IPA workflow.

```bash
xcodebuild \
  -project AirCard17.xcodeproj \
  -scheme AirCard17 \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build
```

The bundled GitHub Actions workflow also packages the unsigned IPA and the TrollStore TIPA, then uploads both as workflow artifacts.

## Credits and license

AirCard17 is an independent derivative focused on Wallet card artwork. The access and filesystem portions are derived from CardioDS, DarkSword, XPF, libgrabkernel2, and Lara. Their notices and the AGPL-3.0 license are retained in this repository.

AirCard17 is not affiliated with Apple, American Express, or any card issuer.
