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

## Updates

The `Excavator` workflow runs every 6 hours: it checks upstream for new releases,
rewrites `version` + `url`, recomputes the hash and commits back to `main`.
No manual work required.

Every `checkver` for a GitHub-hosted app points at a `/releases/latest` endpoint,
which by definition returns the newest release that is neither a prerelease nor a
draft - RC builds are never picked up. The regex matches the asset download URL
rather than the tag, so a release is only accepted if it actually contains the file
the manifest needs. Eight exceptions: `xdoc2txt` (no GitHub) scrapes the x64 zip link
off the ebstudio.info homepage; `vp-bwdif` (upstream ships binaries only as PyPI
wheels since r5) queries the PyPI JSON API for the win_amd64 wheel URL and hash;
`vdf` tracks a rolling nightly release, so its version is the asset's build date
taken from the GitHub release API and every date bump re-hashes the same URL;
`binskim` (binaries ship only on NuGet) watches the NuGet version index, which is
the same feed the nupkg is downloaded from; the four NirSoft utilities read the
version out of NirSoft's PAD manifest, since their download URLs are versionless and
only the hashes change.

Check a single manifest locally against upstream:

```powershell
# from a scoop checkout
bin\checkver.ps1 -App nvencc -Dir <path-to>\scoop-bucket\bucket -Update
```
