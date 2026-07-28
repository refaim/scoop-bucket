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
| `rawwritewin` | Write raw disk images to removable drives | [emeric-martineau/rawwritewin](https://github.com/emeric-martineau/rawwritewin) |
| `ccd2iso` | Convert CloneCD .img images to .iso | [jkmartindale/ccd2iso](https://github.com/jkmartindale/ccd2iso) |
| `xdoc2txt` | Extract plain text from PDF/Office/RTF documents | [ebstudio.info](https://ebstudio.info/home/xdoc2txt.html) |
| `coolreader` | CoolReader 3 e-book reader (pinned, see below) | [crengine](https://sourceforge.net/projects/crengine/) |

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

## Updates

The `Excavator` workflow runs every 6 hours: it checks upstream for new releases,
rewrites `version` + `url`, recomputes the hash and commits back to `main`.
No manual work required.

Every `checkver` for a GitHub-hosted app points at a `/releases/latest` endpoint,
which by definition returns the newest release that is neither a prerelease nor a
draft - RC builds are never picked up. The regex matches the asset download URL
rather than the tag, so a release is only accepted if it actually contains the file
the manifest needs. Two exceptions: `xdoc2txt` (no GitHub) scrapes the x64 zip link
off the ebstudio.info homepage, and `vp-bwdif` (upstream ships binaries only as PyPI
wheels since r5) queries the PyPI JSON API for the win_amd64 wheel URL and hash.

Check a single manifest locally against upstream:

```powershell
# from a scoop checkout
bin\checkver.ps1 -App nvencc -Dir <path-to>\scoop-bucket\bucket -Update
```
