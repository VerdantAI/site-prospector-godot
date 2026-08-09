# Author the vertical

## Why

The prospector answers **where** in two dimensions and cannot be asked **how
high**.

A designer sets `window_origin`, `window_angle_degrees` and `board_lots`, drags
the site around a map seen from directly overhead, and reads a survey. Every
one of those is planar. The vertical dimension — how much backfill sits under
the suburb, and therefore how deep the buried ground is — is **derived and not
authorable**.

Benching bands the terrain, flattens the spread toward a mean, caps risers and
adds an imported depth. Those are four parameters that shape a solve. None of
them is a designer saying *this street sits at this height*.

That contradicts the model the design already states:

> Author the terrain. Author the benches. **The fill is the difference.**

The bench is supposed to be the thing an author draws. It is currently the
thing a solver produces, and the author's only influence is four numbers that
act on the whole board at once.

### The map is the wrong instrument for this

A plan view is the right tool for choosing a parcel and the wrong tool for
choosing a height. **You cannot see fill depth from directly overhead.** The
depth map encodes it as grey, which is a readout rather than a handle: it tells
you the answer after the fact and offers nothing to grab.

Everything the vertical question needs — how much material, how far the ground
drops away, what pokes through — is a thing you look at from the side.

## What changes

**A 3D view of the site**, showing the three surfaces that matter and the space
between them:

| Surface | Is |
| --- | --- |
| **Terrain** | The buried ground, as the region has it |
| **Built** | Benches: what the suburb stands on |
| **Fill** | The volume between them — the isopach, seen as a solid |

**Bench elevations become handles.** Drag a bench up and the fill under it
deepens, the earthwork rises, and the survey follows live. A designer who wants
a street at a particular height sets it there rather than tuning a global
flatten until it happens.

**Ground can be excluded from benching.** Paint a knoll, and it keeps its
terrain while the suburb is filled around it.

## The park is the ground nobody could sell

Excluding ground is the feature this proposal exists for, and it is worth
saying why it is more than a convenience.

**Real suburban parks are the land that could not be built on.** Drainage
easements, flood plains, slopes past the grading budget, knolls too expensive
to level. The developer did not donate them; they were what was left. That is
already how this project handles a *wash* — unbenched ground the suburb
declined to build on — and a park is the same thing inside the built plane
rather than at its edge.

So a park should be an **exclusion**, not a placed object. Authored as a hole in
the benching, it arrives with a reason: the neighbourhood has a hill in it
because grading it flat would have cost more than the lots were worth. Placed as
an object, it is scenery that happens to be green.

This also gives the level a third kind of ground, where it currently has two:

| Ground | Where | Fill |
| --- | --- | --- |
| **Benched** | The suburb | Terrain to bench |
| **Excluded** | Inside the suburb, unbuilt | None — keeps its terrain |
| **Wild** | Outside the suburb | None |

## A left hill gets shorter, and that is correct

If the suburb around a knoll is filled to a given height, the knoll does not
grow — **the ground beside it rises**. A hill standing six metres above the
original terrain stands two metres above a suburb filled four.

That falls out rather than needing rules, and it is the right behaviour: it is
why parks in fill suburbs are often gentle rises rather than the hills they
were. It also means an author raising the benches watches their park sink, which
is exactly the trade-off they should be feeling.

## What this does not do

- **It does not sculpt terrain.** Terrain3D does that, and the terrain is the
  buried ground — the thing excavation recovers. This authors *fill*.
- **It does not replace the map.** Choosing a parcel stays planar and stays
  where it is; this is the second question, asked after the first is answered.
- **It does not decide what a park contains.** An exclusion is unbuilt ground.
  What goes on it is the host project's business.
- **It does not make benching manual.** The solve stays as the starting point;
  authoring overrides it where a designer has an opinion.

## Open questions

- **Per-bench handles, or a painted elevation field?** Handles match how
  benching already works and are fewer things to get wrong. A field is more
  expressive and much easier to make a mess with.
- **How is an exclusion bounded?** A drawn region is direct; "do not bench
  above this grade *here*" is more like the rest of the model and survives the
  terrain changing underneath it.
- **Does a bench wrap around an exclusion, or stop at it?** Wrapping keeps
  streets continuous around a park. Stopping makes the park a barrier, which is
  sometimes what a park is.
- **Does excluded ground accept fill at its margin?** A knoll with a hard edge
  reads as a mesa; real ones have a skirt where the fill laps against them.
- **Is the 3D view the level's own, or the prospector's?** Reusing the host's
  terrain rendering is less to build and couples the addon to whatever the host
  draws ground with.
