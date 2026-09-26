# Stackable Bin Workshop

Parametric OpenSCAD generator for CNC-cut, stackable screw/storage bins. The model was reconstructed from the original S/M/L DXF families and generalized so stock thickness, cutter diameter, relief style, and overall bin size can be changed independently.

![OpenSCAD assembly render](docs/assembly.png)

## Features

- **Parametric bin size** — S, M, L presets or a custom `[width, depth, height]`.
- **Measured stock thickness** — set `wood_thickness` to the actual plywood/MDF thickness.
- **Cutter-driven reliefs** — every CNC relief uses `bit_diameter / 2` as its radius.
- **Relief modes** — `none`, `dogbone`, and `tbone`.
- **Independent fit clearance** — `fit_clearance` changes female mortise width without changing cutter geometry.
- **Flat and assembled outputs** — export a CNC layout to DXF or inspect the assembled 3D model.

## Relief geometry

![OpenSCAD relief test render](docs/relief-test.png)

Both README images are rendered directly from `stackable_bin.scad` by OpenSCAD. No hand-drawn or substitute vector previews are used.

The relief geometry is controlled by the actual cutter diameter:

```scad
bit_diameter = 3.70;
relief_type = "tbone"; // [none,dogbone,tbone]
```

**Dogbone** relief moves the cutter center along the 45-degree bisector of the internal corner. **T-bone** relief moves the cutter center normal to the selected joint wall. Male-tab shoulder relief and female mortise relief both use the same cutter-radius logic.

## Main parameters

| Parameter | Default | Purpose |
| --- | ---: | --- |
| `preset` | `"M"` | `S`, `M`, `L`, or `custom` |
| `custom_size` | `[120,160,100]` | Outside width, depth, stack-pitch height in mm |
| `wood_thickness` | `0.25*inch` | Actual sheet thickness |
| `bit_diameter` | `3.70` | Actual CNC cutter diameter |
| `relief_type` | `"tbone"` | `none`, `dogbone`, or `tbone` |
| `fit_clearance` | `0.15` | Extra width applied to female slots |
| `output` | `"layout"` | `layout`, `assembly`, `side`, `back`, `bottom`, `front`, or `relief_test` |

All dimensions are millimetres. The source defines `inch = 25.4` so imperial stock sizes remain readable.

## Presets

| Preset | Nominal size (W × D × H) |
| --- | --- |
| S | 90 × 120 × 80 mm |
| M | 120 × 160 × 100 mm |
| L | 150 × 200 × 120 mm |

The dimensions describe nominal outside width/depth and stacking pitch height. Joinery and stacking keys are regenerated from the chosen stock thickness rather than uniformly scaling a DXF.

## Usage

Open `stackable_bin.scad` in OpenSCAD, edit the parameters at the top, and choose an output mode.

For a flat CNC layout:

```bash
openscad -o bin-layout.dxf \
  -D 'output="layout"' \
  -D 'preset="M"' \
  -D 'wood_thickness=6.35' \
  -D 'bit_diameter=3.175' \
  -D 'relief_type="tbone"' \
  stackable_bin.scad
```

For an assembly STL:

```bash
openscad -o bin-assembly.stl \
  -D 'output="assembly"' \
  -D 'preset="M"' \
  stackable_bin.scad
```

For a custom 150 × 220 × 120 mm bin:

```bash
openscad -o custom-bin.dxf \
  -D 'preset="custom"' \
  -D 'custom_size=[150,220,120]' \
  -D 'output="layout"' \
  stackable_bin.scad
```

## CNC notes

Measure the actual sheet with calipers and use that value for `wood_thickness`. Set `bit_diameter` to the measured or known cutter diameter. Tune `fit_clearance` separately for your machine, material, and preferred press/slip fit.

Before cutting a full sheet, `output="relief_test"` provides a compact comparison of the unrelieved, dogbone, and T-bone slot geometry.

## Render automation

[GitHub Actions](.github/workflows/render-openscad.yml) regenerates the PNG previews with OpenSCAD whenever the model or render workflow changes, then commits the updated renders under `docs/`.

## Source

The current generator is in [`stackable_bin.scad`](stackable_bin.scad).
