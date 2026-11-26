# Changelog

All notable changes to kadr-cli are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- **`kadr inspect <file>`** shows what a player hides: the size a video is
  stored at and the size it appears on screen, its rotation and mirroring,
  the frame rate it declares and the one measured from every frame's
  timestamp (so a variable frame rate shows), its colour tags and whether it
  is HDR, and each audio track's codec, sample rate and channels. Nothing is
  decoded. `--json` prints the same as JSON, with stable field names, for
  scripts and agents.
- **`kadr thumb <file> --at <time>`** saves the exact frame at a time, upright,
  as PNG, JPEG, HEIC or TIFF, optionally scaled with `--width`.
