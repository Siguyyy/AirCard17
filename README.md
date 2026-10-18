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
