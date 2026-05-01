# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Standalone SketchUp Ruby script that procedurally generates parametric ISO metric threaded rod geometry (currently M10×1.5 mm, L=50 mm). The goal is to evolve it into a full `.rbz` SketchUp plugin — see `FUTURE_PROJECT.md` for the roadmap.

## Loading and Testing

There is no build system. The script is loaded directly in the SketchUp Ruby console:

```ruby
load 'P:/develop/2026/claude/sketchup-filets/vis_M10x1.5_L50_brut.rb'
```

This immediately calls `DanielMaker::ViseM10.create()` and inserts geometry into the active SketchUp model. Visual validation is the only test method — inspect the resulting group in SketchUp for correct thread profile.

## Architecture

### Current file: `vis_M10x1.5_L50_brut.rb`

```
DanielMaker::ViseM10
├── Constants (ISO M10×1.5 parameters)
│   ├── D, P, H, R_MAJOR, R_MINOR, L  — ISO 261/724 geometry
│   ├── N_THETA = 24                   — segments per revolution
│   └── SCALE                          — scale-trick multiplier
├── radius_at(theta, z)                — radial profile function (helical)
└── create()                           — main entry: generates mesh, inserts group
```

**`radius_at(theta, z)`**: computes radial distance as a helical function. Phase-locks `z` to rotation angle, then linearly interpolates between R_MAJOR (crest) and R_MINOR (root) using a two-segment triangular profile.

**`create()`**:
1. Builds per-column arrays of (z, r) pairs — one column per angular segment, z values at every crest/root transition
2. Assembles an N_z × N_THETA vertex matrix, each point multiplied by SCALE
3. Builds a `Geom::PolygonMesh` with dual triangles per quad cell + fan caps at z=0 and z=L
4. Calls `fill_from_mesh(mesh, true, 0)` — `weld=true`, `smooth_flags=0` (sharp edges)
5. Applies inverse `Geom::Transformation.scaling(1/SCALE)` to restore true dimensions
6. Wraps everything in `start_operation` / `commit_operation` for single-undo support

### Key SketchUp API used
- `Sketchup.active_model`, `model.start_operation`, `model.entities.add_group`
- `Geom::Point3d`, `Geom::PolygonMesh`, `Geom::Transformation`
- `group.entities.fill_from_mesh`
- `UI.messagebox`

## Scale-Trick — Critical Pattern

SketchUp's internal tolerance is ~0.0254 mm (0.001″). Thread root-to-crest transitions at M10×1.5 pitch produce vertex deltas well below this threshold, causing edge merging and a corrupted "double-thread" artifact.

**Solution:** construct geometry at `SCALE×` actual size, then apply `Geom::Transformation.scaling(1.0/SCALE)` to the group after `fill_from_mesh`. The recommended value is `SCALE = 100.0` (per FSD and FUTURE_PROJECT). Using `SCALE = 1000.0` without the inverse transform will produce geometry 1000× oversized.

Always verify that **both** steps are present:
1. Points multiplied by SCALE when building the vertex matrix
2. Inverse scaling transformation applied to the group after `fill_from_mesh`

## Planned Plugin Structure (`FUTURE_PROJECT.md`)

The next phase is a parameterized `.rbz` plugin `vis_filets_generator`:

```
vis_filets_generator/
├── vis_filets_generator.rb      # loader, registers extension
└── vis_filets_generator/
    ├── main.rb                  # menu entry + HtmlDialog launcher
    ├── ui_dialog.rb             # HtmlDialog (not deprecated WebDialog)
    ├── geometry.rb              # mesh generator (radius_at + create pattern)
    ├── profiles.rb              # ISO / Trapezoid 30° / Sawtooth profiles
    ├── presets.rb               # M3–M20 ISO tables + FDM preset table
    └── shapes.rb                # Rod, hex bolt (DIN 933), hex nut (DIN 934)
```

**Locked decisions:**
- Scale-trick mandatory, SCALE=100
- `fill_from_mesh` for mesh insertion (not individual face creation)
- `HtmlDialog` for UI
- Right-hand helix only (initial version)
- Metric + FDM profiles in same plugin

## Documentation Files

| File | Purpose |
|------|---------|
| `FSD.md` | Functional specifications — ISO compliance, geometry constraints, robustness rules |
| `JOURNAL.md` | Session-by-session development log with bug root causes |
| `FUTURE_PROJECT.md` | Full roadmap, UI specs, FDM parameters, delivery phases |
| `README.md` | User-facing: ISO tables, usage, known limitations |
