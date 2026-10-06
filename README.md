# Spanorama

**A free, open-source macOS app to position wallpaper & panorama images freely.**

Spanorama gives you control over the desktop picture that macOS doesn't: span a
panorama across multiple displays seamlessly, resize and position images exactly
where you want them, and compose your own desktop from several images.

Inspired by [Fresco](http://glimmir.com/) — reimagined as a modern, MIT-licensed app.

## Download

Grab the latest build from [Releases](https://github.com/iamshakibali/Spanorama/releases).
Every push to `main` produces an automated prerelease build; tagged versions
(`v*`) are stable releases. The zip is ad-hoc signed — right-click the app →
**Open** on first launch, or run `xattr -cr Spanorama.app`.

## Features

- **Panorama spanning** — add one image and it covers the entire canvas of all
  your displays; Spanorama slices it per-display so the image continues
  seamlessly across screen boundaries (the seam lands exactly on the bezel).
- **Free positioning** — drag, scroll-to-zoom (anchored at the cursor), and
  arrow-key nudge images on a live canvas that mirrors your real display layout.
- **Combine images** — layer as many images as you like, with z-order controls,
  duplicates, and per-image fit modes (Fit / Fill / Stretch).
- **Per-display targeting** — snap an image to cover one specific display.
- **One-click apply** — renders at native Retina quality per display and applies
  each slice with no scaling, so pixel alignment is exact.
- **Reset** — restores the wallpapers that were active before Spanorama first ran.
- **Autosave + layouts** — your working layout autosaves; export/import layouts
  as JSON to share or back up.
- **Auto re-apply** (optional) — reapplies your layout when displays connect,
  disconnect, or change resolution.
- **Launch at login** (optional).

## Requirements

- macOS 14 (Sonoma) or newer
- Built with plain Swift Package Manager — **full Xcode is not required**, the
  Command Line Tools alone can build it.

## Build & run

```bash
# run the unit/render test suite
swift run SpanoramaTests

# debug binary
swift build

# assemble a runnable Spanorama.app bundle (release)
./Scripts/build-app.sh release
open dist/Spanorama.app
```

Regenerate the app icon (only needed if `Scripts/make-icon.swift` changed):

```bash
swift Scripts/make-icon.swift build/icon-1024.png
# then build the .iconset → .icns (see Scripts/build-app.sh, or iconutil)
```

## How it works

macOS has no concept of panorama wallpapers — desktop pictures are set per
display. Spanorama:

1. Enumerates every connected display via `NSScreen` and computes the **union
   bounds** as a virtual canvas (display origins can be negative for screens
   left of / above the main display).
2. The editor canvas is that virtual canvas — you position images in real
   screen coordinates.
3. On **Apply**, each display's slice is rendered offscreen at that display's
   native pixel size (Retina displays render at 2×), written to a unique temp
   PNG, and applied with `NSWorkspace.setDesktopImageURL(_:for:options:)`
   using **no scaling** — one image pixel per screen point. That's what makes
   slices line up pixel-perfectly across screens.
4. The editor and the renderer share the same drawing routine, so the preview
   is exactly what gets applied.

## Usage

| Action | Shortcut |
| --- | --- |
| Add images | `⌘O` |
| Add panorama (spans all displays) | `⇧⌘O` |
| Apply to desktop | `⌘R` |
| Move selected layer | drag |
| Scale selected layer | scroll wheel (anchored at cursor) |
| Nudge selected layer | arrow keys (`⇧` for 10 pt steps) |
| Delete selected layer | `⌫` |

## Distribution note (Gatekeeper)

The released bundle is **ad-hoc signed**, not notarized. On first launch,
right-click `Spanorama.app` → **Open**, or run:

```bash
xattr -cr dist/Spanorama.app
```

## Roadmap

- [ ] Light/dark appearance wallpaper pairing
- [ ] Menu bar quick-apply mode
- [ ] Corner handles for direct resize
- [ ] Notarized builds

## Contributing

Issues and PRs welcome. Keep PRs small and focused.

## License

[MIT](LICENSE) — © 2026 Spanorama contributors
