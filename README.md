# Site Prospector

Choose where a level sits on a large terrain, and survey the ground before you
build on it.

Ground is authored once, over kilometres. A level is a **rectangle cut from it**
at whatever angle the land rewards. This addon is the pair of tools for making
that choice: a map you drag a site around on, reading the ground under it live,
and an optional sweep that ranks candidates for you.

> **Status: 0.x.** The API is still moving. It will be submitted to the
> [Godot Asset Store](https://store.godotengine.org/) once a second project has
> been sited with it — one project cannot expose the assumptions still baked in.

## Reference real topography; generate at game scale

Real elevation data cannot be cropped into a level, and this is the mistake the
addon exists to stop you making.

|  | A real alluvial fan | A game board |
| --- | --- | --- |
| Length | ~2.5 km | 204 m |
| Relief | ~150 m | 12 m |
| Gradient | **~6%** | **~6%** |

**Gradient transfers at 1:1. Extent does not.** A board is a fraction of a real
landform's length, so it holds that fraction of its relief. Crop a DEM to 200 m
and you get ground that is nearly flat; stretch it to fill a relief budget and
you get mountains. Neither is playable, and both look wrong immediately.

So read real sheets for their *grammar* — how a fan spreads from a canyon
mouth, how a wash braids, where a street stops — and generate ground at game
scale. At 1:1 metres, **choose features that fit rather than shrinking features
that do not**: a 15 m barranca interrupts a board and belongs on it; a 200 m
wash *is* the board and belongs in a neighbouring region.

## What you get

- **`RegionLandform`** — a parametric region: a range front with embayments,
  alluvial fans spreading from canyon mouths, coalescing into a bajada, incised
  by arroyos. Every feature is in metres, so the ground does not change when a
  level does.
- **`RegionProspect`** — a 2D scene. Drag the site rectangle; the survey under
  it updates live.
- **`SurveyLayer`** — the extension point. Fertility and minerals ship as
  examples; soil depth, water and anything else answer the same three questions.
- **`RegionWindow`** — the level's window onto the region: an origin and an
  angle, and nothing else.
- **`render_region_map.gd`** — topographic and height maps, plus an optional
  sweep that ranks candidate sites by contours crossed.

## The survey

Dragging the site reports what a surveyor would want, not what a level editor
finds convenient:

```
(1503, 513) m at -26 deg
9 x 17 lots  -  108 x 204 m
elevation 43 - 54 m  (relief 11.5)
mean grade 9%
87% buildable  -  133 lots
drainage 18 lots
6 benches, deepest fill 4.4 m
earthwork 29,727 m3
0.32 contours/lot
fertility 33%  -  16 of 153 lots good
iron 0  -  0 of 153 lots good
good ground
```

**100% buildable with no drainage is a failure, not a success.** It means an
unbroken grid on flat ground: nothing to dig, and no reason for a street to
stop.

## Installation

1. Install **[automate-godot](https://github.com/VerdantAI/automate-godot)**
   into `addons/automate_godot/`. It is required — benching, fill depth and
   earthwork are reported from it.
2. Copy `addons/site_prospector/` into your project's `addons/` directory.
3. **Project → Project Settings → Plugins** and enable **Site Prospector**.

The plugin says so plainly if the dependency is missing rather than failing
somewhere deeper.

## Using it

1. **Open the map.** The dock's first button opens the prospect scene in 2D and
   draws the region from the landform — there is nothing to generate first.
2. **Drag the `Site` node.** The survey follows it. Set `board_lots` if your
   level is not 9 × 17.
3. **Tick `keep this site`** in the Inspector. It writes `chosen_site.tres`.
4. **Apply it.** Open the scene holding your `RegionWindow` and press *Apply
   kept site*.

Optionally, **Rank candidate sites** sweeps the whole region and ranks
rectangles at every angle by contours crossed — the flattest large parcel, the
way a developer reads a sheet. It takes about a minute and is never required.

## Settings, and where they live

Three scopes, and which one a setting belongs in is a real decision rather
than a filing preference.

| Home | Scope | Committed | Holds |
| --- | --- | --- | --- |
| **Project Settings** | The project | Yes, in `project.godot` | `site_prospector/prospect_scene`, `site_prospector/chosen_site` |
| **Editor Settings** | The developer, every project | No, in `~/.config` | `site_prospector/assistant/host`, `.../model`, `.../enabled` |

**What every teammate must agree on goes in the project.** Which scene is this
project's map is a fact about the project, and a checkout without it is broken.

**What describes a machine goes in the editor.** A model host URL and a model
name are the same across every project that developer opens and wrong for
everyone else on their team. Committing one person's `localhost:11434` to a
shared `project.godot` makes the file churn on every machine and be right on
none of them.

**A credential belongs in neither.** Both settings files are plain text on
disk and one of them is in git. When hosted endpoints are supported, the key
comes from an environment variable and only the variable's *name* is recorded.

## Demo

This repository is a Godot project. Open it, enable the plugin, and
`demo/prospect_demo.tscn` is a working region with fertility and iron layers.

## Licence

MIT. See [LICENSE](LICENSE).
