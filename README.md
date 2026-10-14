# FrameWise

FrameWise is an offline-first iOS camera app that helps users compose better
photos in real time. It will combine a custom camera, composition overlays,
reference-photo alignment, and on-device AI guidance.

> Current state: the Windows + WSL2 + xtool development pipeline is set up,
> and the branded camera foundation plus persistent captured-photo library are
> implemented. The iOS app builds with the Open Crop icon, state-driven opener,
> camera permission recovery, live preview shell, still capture service,
> capture-to-library flight animation, Library/Preview navigation, native Share,
> add-only Save-to-Photos export, FrameWise-only Delete, and a disabled Edit
> placeholder.

## Product and design documents

- [Product design](docs/superpowers/specs/2026-10-12-ai-composition-camera-design.md)
- [Layout and visual design](docs/superpowers/specs/2026-10-12-framewise-layout-design.md)
- [Camera foundation design](docs/superpowers/specs/2026-10-13-camera-foundation-design.md)
- [Code walkthrough](docs/code-walkthrough.md)

## Verified setup

Verified on 2026-10-12 from Ubuntu running under WSL2:

- Swift 6.4.0 installed through Swiftly.
- xtool 1.21.0 installed and available in the Ubuntu shell.
- Darwin SDK installed through xtool in slim mode.
- iPhoneOS 27.1 and iPhoneSimulator 27.1 SDKs installed.
- xtool Apple authentication completed.
- Physical iPhone detected by `idevice_id` and `xtool devices --usb`.
- Starter SwiftUI app built successfully with `xtool dev`.
- The current camera foundation builds successfully with `xtool dev build`.
- Physical-device camera verification is the next validation step for this
  slice; personal Apple account details and the device UDID are not stored in
  this repository.

Personal Apple account details and the device UDID are intentionally not
stored in this repository.

## Project structure

```text
FrameWise/
├── Package.swift
├── xtool.yml
├── Sources/
│   ├── FrameWise/
│   │   ├── FrameWiseApp.swift
│   │   ├── ContentView.swift
│   │   ├── Branding.swift
│   │   ├── BrandIntroView.swift
│   │   ├── CameraService.swift
│   │   ├── CameraViewModel.swift
│   │   ├── CapturedPhotoStore.swift
│   │   ├── CameraPreview.swift
│   │   ├── CameraScreen.swift
│   │   ├── LibraryView.swift
│   │   ├── PhotoGalleryView.swift
│   │   ├── PhotoPreviewView.swift
│   │   ├── PhotoLibraryWriter.swift
│   │   └── ShareSheet.swift
│   └── FrameWiseCore/
│       ├── CameraState.swift
│       ├── CameraStateReducer.swift
│       ├── BrandingTokens.swift
│       ├── CapturedPhoto.swift
│       ├── CapturedPhotoGrouping.swift
│       ├── CapturedPhotoLibrary.swift
│       └── CapturedPhotoDiskStore.swift
├── Tests/FrameWiseCoreTests/
│   ├── CameraStateReducerTests.swift
│   ├── BrandingTokenTests.swift
│   ├── CapturedPhotoGroupingTests.swift
│   ├── CapturedPhotoLibraryTests.swift
│   └── CapturedPhotoDiskStoreTests.swift
├── Resources/
│   ├── FrameWiseAppIcon.svg
│   ├── FrameWiseAppIcon.png
│   ├── FrameWiseClearLogo.svg
│   └── FrameWiseClearLogo.png
├── FrameWise-Info.plist
└── docs/
    └── superpowers/specs/
```

The core state target is hardware-independent so the reducer and persistent
photo tests run on the host. `CapturedPhotoDiskStore` writes one image file per
capture plus an atomic manifest under the app's private Application Support
directory. `CapturedPhotoStore` loads that library again on relaunch and only
publishes a new item after the private write succeeds. The camera target is the
iOS-facing layer; its AVFoundation work stays in `CameraService`, while SwiftUI
reads state through `CameraViewModel` and shares one photo store across Camera,
Library, and Preview.

## Captured photo flow

- Capture stays on Camera. After the private app-storage write succeeds, the
  live preview remains visible while a contained capture card holds briefly,
  then smoothly shrinks into the dock's Library thumbnail. Reduced Motion uses
  an opacity-only completion transition. Rapid captures are queued until each
  private write succeeds, and a failed write exposes a retry path.
- Library restores stored captures after relaunch and offers By Day groups plus
  an All Photos mode. Each day group opens a newest-first three-column gallery;
  the lower-right Camera button returns to the existing camera root without
  creating a second camera session.
- Preview offers native Share, Save, and Delete actions. Share uses the system
  share sheet without Photos permission. Save requests Photos **add-only**
  access and exports a copy only after the user chooses Save. Delete removes
  only the private FrameWise copy and never removes an already-exported Photos
  copy. Edit is visible but disabled until the editing slice is implemented.
- FrameWise never requests Photos read access and does not upload captures to a
  network service.
The bundle ID in `xtool.yml` is still the generated placeholder and should be
changed before distributing the app.

The app icon is a single PNG with a black background, white Open Crop frame,
and Signal Coral center, packaged through `iconPath` in `xtool.yml`. iOS may
still apply its own Dark and Clear Home Screen styling; Clear presentation is
rendered as monochrome glass. The opener and recovery surfaces follow the
device's system light/dark appearance, while the Ink and Signal Coral brand
tokens stay fixed.

## Normal development commands

### Start a new session

Connect the iPhone, unlock it, and keep the Apple Devices app available on
Windows. Then run this in Ubuntu:

```bash
cd "/mnt/c/Source Code/Mobile App/FrameWise"
source /home/aaronjay/.bashrc
idevice_id -l
xtool devices --usb
```

### Build, sign, install, and run on the iPhone

```bash
cd "/mnt/c/Source Code/Mobile App/FrameWise"
xtool dev
```

Run this again after code changes. The iPhone must be connected for install
and device testing.

### Build without installing

```bash
xtool dev build
```

This is useful when the iPhone is disconnected. A physical iPhone is still
required to test the camera, permissions, performance, and on-device AI.

## Important WSL build configuration

Swift build output must stay on the Linux filesystem. The project source is
on the Windows drive, but `.build` is a symlink to Ubuntu storage:

```text
/mnt/c/Source Code/Mobile App/FrameWise/.build
→ /home/aaronjay/framewise-build
```

This avoids WSL/NTFS rename failures during parallel Swift compilation.

Check it with:

```bash
readlink -f .build
```

Expected output:

```text
/home/aaronjay/framewise-build
```

If the link is missing, recreate it. `.build` contains generated artifacts;
it is not source code:

```bash
cd "/mnt/c/Source Code/Mobile App/FrameWise"
rm -rf .build
mkdir -p /home/aaronjay/framewise-build
ln -s /home/aaronjay/framewise-build .build
```

## iPhone transport on Windows + WSL

The recommended deployment path uses the Windows Apple Devices service and
forwards Apple’s usbmuxd service into WSL. This is more reliable for xtool
installation than raw USB/IP passthrough.

### One-time Windows setup

Install and open [Apple Devices](https://apps.microsoft.com/detail/9np83lwlpz9k).
Connect the iPhone, unlock it, and accept the trust prompt.

If the iPhone is still attached to WSL through usbipd, detach it from normal
Windows PowerShell:

```powershell
usbipd detach --busid 2-3
```

In Ubuntu, find the WSL gateway:

```bash
ip route list default
```

Use the IP shown after `default via` in **Administrator PowerShell**:

```powershell
$wslGateway = "REPLACE_WITH_GATEWAY_IP"

New-NetFirewallRule -DisplayName "WSL Apple usbmuxd" -Direction Inbound -Action Allow -Protocol TCP -LocalAddress $wslGateway -LocalPort 27015 -Profile Any

netsh interface portproxy set v4tov4 listenaddress=$wslGateway listenport=27015 connectaddress=127.0.0.1 connectport=27015
```

The firewall and port-forward rules are normally one-time setup. If the WSL
gateway IP changes after a restart, update the port-forward rule.

### WSL environment variable

The following line should be in `/home/aaronjay/.bashrc`:

```bash
export USBMUXD_SOCKET_ADDRESS="$(ip route list default | awk '{print $3}'):27015"
```

It is already applied automatically for new Ubuntu shells. To apply it to an
existing shell:

```bash
source /home/aaronjay/.bashrc
```

Do not use `usbipd attach` for the iPhone at the same time as this Apple
Devices transport.

## Common troubleshooting

### `xtool devices --usb` shows no iPhone

- Confirm the iPhone is unlocked.
- Accept **Trust This Computer** on the iPhone.
- Confirm Apple Devices can see the iPhone on Windows.
- Run `source /home/aaronjay/.bashrc`.
- Run `idevice_id -l` before running xtool.

### xtool stops at `[Connecting] 100%`

- Keep the iPhone connected and unlocked.
- Make sure Apple Devices is installed and can see the iPhone.
- Confirm the iPhone is detached from usbipd.
- Check that `USBMUXD_SOCKET_ADDRESS` is set in the current Ubuntu shell.
- If the WSL gateway changed, update the Windows port-forward rule.

### iOS says the developer is untrusted

On the iPhone, open **Settings → General → VPN & Device Management**, select
the Apple Development profile, and choose **Trust** or **Allow & Restart**.
Developer Mode is under **Settings → Privacy & Security → Developer Mode**.

## What is next

1. Verify the branded opener, permission recovery, camera switching, and
   still capture on a connected iPhone, including Reduced Motion.
2. Add rule-of-thirds, golden spiral/Fibonacci, and horizon overlays.
3. Add the AI Guide UI: subject marker, target dot, arrow, and short label.
4. Add reference-photo overlay with opacity, scale, position, and lock.
5. Add offline Vision/Core ML scene analysis for scenery and landscapes.
6. Add the composition recommendation and alignment engine.
7. Ensure exported photos exclude all guides, arrows, labels, and reference
   overlays.
8. Add device testing for low confidence, alignment stability, battery use,
   and reduced motion.

## Product rules to preserve

- AI Auto may recommend a composition, but Manual Guide selection is never
  silently replaced.
- Reference images stay local unless the user explicitly shares them.
- Capture and guidance work without an online AI service.
- Guidance should show one clear instruction at a time.
- Low-confidence analysis should say that no clear subject was detected.
