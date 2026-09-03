# scoop-bucket

Personal [Scoop](https://scoop.sh) bucket.

```powershell
scoop bucket add refaim https://github.com/refaim/scoop-bucket
scoop install refaim/nvencc
```

| App | Description | Upstream |
| --- | --- | --- |
| `nvencc` | NVENC/NVDEC hardware video encoder CLI | [rigaya/NVEnc](https://github.com/rigaya/NVEnc) |
| `mkclean` | Optimise and repair Matroska files | [matroska.org](https://www.matroska.org/downloads/mkclean.html) |
| `dovi_tool` | Dolby Vision RPU/metadata CLI (x64 + arm64) | [quietvoid/dovi_tool](https://github.com/quietvoid/dovi_tool) |
| `cjpegli` | jpegli JPEG encoder (pinned, see below) | [libjxl/libjxl](https://github.com/libjxl/libjxl) |
| `vp-bestsource` | VapourSynth source filter (FFmpeg-based) | [vapoursynth/bestsource](https://github.com/vapoursynth/bestsource) |
| `vp-vship` | VapourSynth GPU metrics plugin (CUDA build) | [Line-fr/Vship](https://codeberg.org/Line-fr/Vship) |
| `vp-bwdif` | VapourSynth deinterlacing plugin (FFmpeg bwdif) | [HolyWu/VapourSynth-Bwdif](https://github.com/HolyWu/VapourSynth-Bwdif) |
| `bg3mm` | Baldur's Gate 3 mod manager | [LaughingLeader/BG3ModManager](https://github.com/LaughingLeader/BG3ModManager) |
| `rawwrite` | Write raw disk images to removable drives | [emeric-martineau/rawwritewin](https://github.com/emeric-martineau/rawwritewin) |
| `ccd2iso` | Convert CloneCD .img images to .iso | [jkmartindale/ccd2iso](https://github.com/jkmartindale/ccd2iso) |
| `xdoc2txt` | Extract plain text from PDF/Office/RTF documents | [ebstudio.info](https://ebstudio.info/home/xdoc2txt.html) |
| `coolreader` | CoolReader 3 e-book reader (pinned, see below) | [crengine](https://sourceforge.net/projects/crengine/) |
| `scanner` | Sunburst disk space visualizer (pinned, see below) | [steffengerlach.de](http://www.steffengerlach.de/freeware/) |
| `vdf` | Video Duplicate Finder GUI (rolling nightly) | [0x90d/videoduplicatefinder](https://github.com/0x90d/videoduplicatefinder) |
| `codex-minibar` | Tray monitor for ChatGPT/Codex usage limits | [vertopolkaLF/codex-minibar](https://github.com/vertopolkaLF/codex-minibar) |
| `binskim` | Binary security static analysis (PE/ELF) | [microsoft/binskim](https://github.com/microsoft/binskim) |
| `snapjaw` | Git-based WoW AddOn manager for Vanilla and WotLK 3.3.5 | [refaim/snapjaw](https://github.com/refaim/snapjaw) |
| `gwent-tracker` | Track Gwent card collection progress from The Witcher 3 saves | [rfvgyhn/gwent-tracker](https://github.com/rfvgyhn/gwent-tracker) |
| `divine` | LSLib CLI for Divinity: Original Sin and Baldur's Gate 3 files | [Norbyte/lslib](https://github.com/Norbyte/lslib) |
| `hdr10plus_tool` | HDR10+ metadata CLI (extract, inject, convert) | [quietvoid/hdr10plus_tool](https://github.com/quietvoid/hdr10plus_tool) |
| `shellmenuview` | Disable unwanted static Explorer context-menu items | [nirsoft.net](https://www.nirsoft.net/utils/shell_menu_view.html) |
| `shellexview` | List and disable installed shell extensions | [nirsoft.net](https://www.nirsoft.net/utils/shexview.html) |
| `uninstallview` | Every installed program from every registry hive in one list | [nirsoft.net](https://www.nirsoft.net/utils/uninstall_view.html) |
| `bluescreenview` | Read blue screen crash dumps and blame the driver | [nirsoft.net](https://www.nirsoft.net/utils/blue_screen_view.html) |
| `numi` | Text calculator - write the sum as a sentence, read the answer | [numi.app](https://numi.app) |
| `ffmpeg8-shared` | FFmpeg 8.x shared libraries (pinned, see below) - dependency of `vdf` | [GyanD/codexffmpeg](https://github.com/GyanD/codexffmpeg) |

`vp-bestsource`, `vp-vship` and `vp-bwdif` are VapourSynth plugins, not programs. The
DLL stays inside the package directory - link it into your plugin path yourself. All
keep a stable file name, so a link to `...\apps\<name>\current\<dll-name>` survives
updates.

`cjpegli` is pinned to libjxl v0.11.2 and has no `checkver`: v0.12.0 dropped
`cjpegli.exe` from every Windows archive, so an automatic bump would install a build
without the tool.

`coolreader` is pinned to 3.1.2-49, the last Windows build upstream ever produced
(October 2014). Every newer CoolReader release is Android-only, so there is nothing
for `checkver` to find.

`scanner` is pinned to 2.13 (July 2012): the download URL is versionless, the site is
HTTP-only and upstream has been dormant ever since, so the fixed hash is the whole
integrity story.

`ffmpeg8-shared` is pinned to the FFmpeg 8.x series and exists only so `vdf` can keep
its fast native FFmpeg binding. `VDF.Core` pins `FFmpeg.AutoGen 8.1.0`, which
P/Invokes `avcodec-62.dll`, `avutil-60.dll` and `avformat-62.dll` by name, while
`main/ffmpeg-shared` has moved to 9.x - `avcodec-63`, `avutil-61`, `avformat-63`. It
declares no `env_add_path`, no `env_set` and no shims, so it never fights
`main/ffmpeg-shared` over the `ffmpeg.exe` shim or `FFMPEG_DIR` and the two coexist;
only apps reaching into `...\apps\ffmpeg8-shared\current\bin` themselves see it.
Install it for a general-purpose ffmpeg and you will get nothing on your PATH. A
mismatch is not fatal either way: VDF probes its `bin` for the exact file names,
turns the native binding off when they are missing and scans through the slower
`ffmpeg.exe` process path. Retire the manifest once upstream VDF moves to a 9.x
binding - `vdf` already prefers this package but falls back to `main/ffmpeg-shared`.

The four NirSoft utilities - `shellmenuview`, `shellexview`, `uninstallview` and
`bluescreenview` - also exist in the official
[ScoopInstaller/Nirsoft](https://github.com/ScoopInstaller/Nirsoft) bucket, the first
two named after their exes (`shmnview`, `shexview`) rather than the products. These
copies persist the `.cfg` through a `pre_install` that pre-creates the file, so scoop
links a file rather than turning the missing config into a directory junction. The
utilities rewrite that file in place when the window closes, so the hard link holds
and settings survive an update. The `*_lng.ini` translation file is left unpersisted
on purpose: it only exists once you run `/savelangfile`, and an empty placeholder
would load as an empty translation.

`numi` is not installed from the `numi-setup.exe` the site links, but from the
Squirrel update feed the app itself polls: the same build, shipped as a nupkg under a
per-version URL, so every release gets its own hash and there is no installer to
unpack a second time. In-app updates are dead by design - Squirrel's `Update.exe` is
left out, so the app logs `Can not find Squirrel` once at startup and carries on;
`scoop update numi` does the job instead. Notes and preferences live in
`%APPDATA%\Numi` and are neither persisted nor removed on uninstall.

## Updates

The `Excavator` workflow runs every 6 hours: it checks upstream for new releases,
rewrites `version` + `url`, recomputes the hash and commits back to `main`.
No manual work required.

Every `checkver` for a GitHub-hosted app points at a `/releases/latest` endpoint,
which by definition returns the newest release that is neither a prerelease nor a
draft - RC builds are never picked up. The regex matches the asset download URL
rather than the tag, so a release is only accepted if it actually contains the file
the manifest needs. Ten exceptions: `xdoc2txt` (no GitHub) scrapes the x64 zip link
off the ebstudio.info homepage; `vp-bwdif` (upstream ships binaries only as PyPI
wheels since r5) queries the PyPI JSON API for the win_amd64 wheel URL and hash;
`vdf` tracks a rolling nightly release, so its version is the asset's build date
taken from the GitHub release API and every date bump re-hashes the same URL;
`binskim` (binaries ship only on NuGet) watches the NuGet version index, which is
the same feed the nupkg is downloaded from; the four NirSoft utilities read the
version out of NirSoft's PAD manifest, since their download URLs are versionless and
only the hashes change; `numi` (the GitHub repo carries only the CLI and plugins,
never the desktop app) takes the last line of the Squirrel `RELEASES` index, the same
file the app reads when it checks for an update; `ffmpeg8-shared` deliberately walks
the whole release list instead of `/releases/latest`, since latest is 9.x, and only
accepts an 8.x shared asset - once 8.x scrolls off that page of 100 the match simply
stops and the version stays put, which is the safe failure.

Check a single manifest locally against upstream:

```powershell
# from a scoop checkout
bin\checkver.ps1 -App nvencc -Dir <path-to>\scoop-bucket\bucket -Update
```
