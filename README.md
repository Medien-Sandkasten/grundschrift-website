# Grundschrift website

Static website for the Grundschrift app, served by GitHub Pages from the
repository root (`.github/workflows/deploy.yml`). No frameworks, no external
requests.

## Editing

Pages live in `src/pages/*.html` (front matter + body). Header, footer and
`<head>` are rendered in one place by the generator. After every change:

```bash
dart tool/build.dart   # writes *.html, sitemap.xml and robots.txt to the root
dart tool/check.dart   # links, one h1 per page, landmarks, meta, AA contrast
```

Commit the generated files together with their sources. The generated `.html`
files in the root must not be edited by hand.

`datenschutz.html` must keep its URL; the app links to it.

## Letter demos

`src/letters.json` and `assets/levels/` come from the open level data of the
app (`grundschrift_flutter/assets/levels/`, AGPL-3.0). To change the selection,
edit the list in `tool/import_levels.dart` and run:

```bash
dart tool/import_levels.dart <path-to>/grundschrift_flutter/assets/levels
```

Never import the app's illustrations or recordings: they are third-party
material and not under a free licence.

## Screenshots

`src/screens.json` lists the app screenshots, with alt texts and captions,
and a crop box per screenshot that leaves out every protected illustration
and icon. They are rendered from the app into
`grundschrift_flutter/build/website_screenshots/`. Import them (needs
`cwebp`) and rebuild:

```bash
dart tool/import_screens.dart <path-to>/grundschrift_flutter/build/website_screenshots
dart tool/build.dart
```

As long as `"illustrations_allowed": false`, only the crops are published, and
screenshots without a crop are left out of the pages. Set it to `true` only once
the rights holder has confirmed that the full screenshots may be shown on this
website; the import then writes the full screenshots, removes the crops and
switches the licence notes on the site and in this README. `tool/build.dart`
refuses to build while the files in `assets/img/screens/` do not match the
setting.

## Assets and licences

| Path | Source | Licence |
|---|---|---|
| `assets/levels/`, `src/letters.json` | level data of the app | AGPL-3.0 |
| `assets/img/finger.png`, `assets/img/star.png` | public image set of the app (`tool/asset_policy.json`) | AGPL-3.0 |
| `assets/fonts/grundschrift-gsv.woff2` | Grundschrift GSV, unmodified WOFF2 conversion | SIL OFL 1.1 (`assets/fonts/OFL.txt`) |
| `assets/img/og.png`, `apple-touch-icon.png` | rendered from the font and the level `a` | AGPL-3.0 / OFL 1.1 |
| `assets/img/screens/` | screenshots of the app, cropped so that no protected illustrations or icons are visible (`src/screens.json`) | AGPL-3.0 |
| `images/laborschule_logo.png`, `images/gsv_logo.png` | partner marks | rights remain with the partners |
| `images/grundschrift_icon.png` | existing site icon | provenance to be confirmed |
