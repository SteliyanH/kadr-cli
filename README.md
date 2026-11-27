# kadr-cli

Command-line tools for video, built on [kadr](https://github.com/SteliyanH/kadr).

```console
$ kadr inspect IMG_0412.MOV
IMG_0412.MOV  48.2 MB  0:12.48

Video     HEVC, 1080×1920 on screen, stored 1920×1080 and rotated 90°
          30 fps declared, 24–30 fps measured: variable (341 frames)
          HDR (HLG), BT.2020 primaries, BT.2020 matrix
          29.9 Mbit/s
Audio     AAC, 44.1 kHz, stereo, 173 kbit/s
```

A player shows a portrait clip upright, plays a variable frame rate smoothly and
tone-maps HDR, so none of that is visible by watching. All of it changes what an
edit exports, and all of it is in the file. `kadr inspect` reads it from the
container without decoding a frame, so a long file takes a moment.

## Install

Needs macOS 14 and Xcode 26 (Swift 6.2).

```sh
git clone https://github.com/SteliyanH/kadr-cli.git
cd kadr-cli
swift build -c release
cp .build/release/kadr /usr/local/bin/   # or anywhere on your PATH
```

Or run it in place with `swift run kadr inspect clip.mov`.

## `kadr inspect <file>`

For each video track:

- **Size**: as stored, and as shown once the rotation is applied, which is the
  size kadr fits into the frame. Phones store portrait video as landscape pixels
  and a rotation.
- **Rotation and mirroring**: the clockwise turn a player applies, and whether
  the picture is flipped, as a front camera can store it.
- **Frame rate**: the rate the file declares, and the rate measured from every
  frame's timestamp. In low light an iPhone drops to 24 fps or below while still
  declaring 30. A rate is reported as variable when its fastest frames run more
  than 10% faster than its slowest; the rounding in a 29.97 fps file stays
  under that.
- **Colour**: primaries, transfer function and matrix, and whether it is HDR
  (HLG or PQ).
- **Codec and bit rate**.

For each audio track: codec, sample rate, channels and bit rate.

### `--json`

The same report as JSON, for scripts and agents:

```sh
kadr inspect clip.mov --json | jq '.video[0].frameTiming.isVariable'
```

Field names are stable: new fields are added, existing ones are not renamed or
removed. A field the file doesn't record (a colour tag, the bits per component)
is left out rather than guessed. The fields are documented on
[`MediaReport`](Sources/KadrCLIKit/MediaReport.swift).

## `kadr thumb <file> --at <time>`

```console
$ kadr thumb IMG_0412.MOV --at 0:04.5 --width 540
IMG_0412-4.5s.png  540×960
```

Saves the frame at a time: the exact frame, not the nearest keyframe (which can
be seconds away), and upright, so a portrait clip gives a portrait image.

- `-a, --at`: seconds (`12.5`) or minutes and seconds (`1:02.5`). Defaults to
  the first frame.
- `-o, --output`: the file to write. The extension picks the format: `.png`,
  `.jpg`, `.heic` or `.tiff`. Defaults to `<name>-<time>s.png` in the current
  directory.
- `-w, --width`: scale to this many pixels wide, keeping the shape.

## Planned

- `kadr render`: export a composition from a project file.
- `kadr-mcp`: the same tools for agents, as an MCP server.

## Contributing

Issues and pull requests are welcome. Contributions are accepted under kadr's
[Contributor License Agreement](https://github.com/SteliyanH/kadr/blob/main/CLA.md),
which you sign once, on your first pull request, for every kadr repository.

## License

Apache 2.0. See [LICENSE](LICENSE).
