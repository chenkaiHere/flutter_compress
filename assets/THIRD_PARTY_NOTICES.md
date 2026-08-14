# Third-party notices

These files are vendored into `assets/` and ship inside the **web** build output
of any app that uses this plugin. They are loaded lazily — only when video
compression is first used on web — so an app that never compresses video on web
never downloads them. Image compression on web needs neither.

Both are shipped **unmodified** from upstream.

| File | Size | Upstream | Licence |
|---|---|---|---|
| `mp4box.all.min.js` | 144 KB | [gpac/mp4box.js](https://github.com/gpac/mp4box.js) | BSD-3-Clause |
| `mp4-muxer.js` | 72 KB | [Vanilagy/mp4-muxer](https://github.com/Vanilagy/mp4-muxer) | MPL-2.0 |

`flutter_compress_web.js` (20 KB) is this plugin's own code and is covered by the
plugin's MIT licence.

## What this means for you

Neither licence restricts commercial or closed-source use of your app, and
neither is triggered by merely calling into these files. Both do require that
the licence notice travel with the copy — which is what this file is for.

MPL-2.0 is file-level copyleft: if you **modify** `mp4-muxer.js` itself, the
modified file must stay MPL-2.0 and its source must be made available. Using it
as-is, which is what this plugin does, imposes nothing on your own code.

> Verify these identifiers against upstream before you rely on them for a
> compliance review — the vendored bundles carry no licence header of their own,
> and upstream can relicense between releases.
