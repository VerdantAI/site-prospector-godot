# site-authoring

## ADDED Requirements

### Requirement: A designer SHALL set bench elevations directly

A bench's elevation SHALL be settable by the designer, and the derived solve
SHALL act as the starting point rather than the only answer. Setting one bench
SHALL NOT require re-tuning parameters that act on the whole board.

The model this project states is that an author draws the bench and the fill is
the difference. Benching currently produces bench elevations from four global
parameters, so a designer wanting one street at one height has to tune a
board-wide flatten until it happens by accident. That is not authoring, it is
negotiation with a solver.

#### Scenario: One bench is raised

- **GIVEN** a solved set of benches
- **WHEN** the designer raises a single bench
- **THEN** that bench sits where it was put, its fill deepens, and no other
  bench moves except as the riser cap requires

#### Scenario: The terrain changes underneath an authored bench

- **GIVEN** a bench whose elevation was set by hand
- **WHEN** the region's landform changes
- **THEN** the authored elevation is kept and the fill is re-derived against
  the new terrain, rather than the authoring being silently discarded

### Requirement: Ground SHALL be excludable from benching

Ground inside the built plane SHALL be markable as excluded, and excluded
ground SHALL keep its terrain elevation and carry no fill.

A suburb's parks are the land that could not be built on - drainage easements,
flood plains, slopes past the grading budget, knolls too expensive to level.
Modelling a park as an exclusion gives it that cause; modelling it as a placed
object makes it scenery that happens to be green. The project already treats a
wash this way at the edge of the board, and this is the same thing inside it.

#### Scenario: A knoll is kept

- **GIVEN** a rise inside the area being benched
- **WHEN** the designer excludes it
- **THEN** the suburb is filled around it, the knoll keeps its terrain, and its
  fill is zero

#### Scenario: The suburb around an exclusion is raised

- **GIVEN** an excluded knoll standing above the terrain around it
- **WHEN** the benches beside it are raised
- **THEN** the knoll's height above the built ground falls by the amount the
  fill rose, because the ground beside it came up and the knoll did not

#### Scenario: Excluded ground is reported

- **WHEN** a site is surveyed
- **THEN** excluded lots are counted separately from benched lots and from wild
  ground outside the board, because the three are different kinds of ground

### Requirement: The vertical SHALL be authored in a view that shows it

Fill height SHALL be authored in a view showing the terrain, the built surface
and the volume between them. A plan view SHALL NOT be the only surface offered
for it.

Depth cannot be seen from directly overhead. The depth map encodes it as a
grey value, which reports an answer and offers nothing to grab; every question
the vertical raises - how much material, how far the ground falls away, what
still pokes through - is one a person answers by looking from the side.

#### Scenario: A designer judges fill depth

- **WHEN** the vertical is being authored
- **THEN** the terrain, the built surface and the fill between them are all
  visible at once

#### Scenario: A bench is moved

- **WHEN** a bench elevation changes
- **THEN** the fill volume, the earthwork total and the survey update without
  the designer leaving the view or re-running a tool

### Requirement: Authoring the vertical SHALL NOT edit the terrain

Authoring SHALL change only the fill and which ground is benched. The terrain
SHALL remain the region's, unedited by this tool.

The terrain is the buried ground - the thing excavation recovers and the thing
the whole premise rests on. A tool that let a level author edit it would let a
level quietly disagree with the region it was cut from, and would put the
paleotopography in the hands of whoever was last adjusting a street height.

#### Scenario: Fill is authored

- **WHEN** any bench elevation or exclusion changes
- **THEN** the region's landform is untouched, and another level cut from the
  same region sees the same terrain

#### Scenario: The ground is wanted lower than the terrain

- **WHEN** a bench is set below the terrain beneath it
- **THEN** the fill is zero rather than negative, and the shortfall is reported
  as a cut rather than silently lowering the ground
