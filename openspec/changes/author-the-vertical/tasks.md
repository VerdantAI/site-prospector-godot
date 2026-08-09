## Tasks

The plan, 2026-08-09.

**Phase 0 is the whole question.** Everything after it is refinement of
something that either felt like authoring or did not, and the way to find out
is to leave a hill in a neighbourhood and see whether it reads as a park or as
a mistake.

---

## Phase 0 - See the fill, and change it

- [ ] A 3D view of the site: terrain, built surface, and the fill between them
      as a solid.
- [ ] Bench elevations are handles. Drag one; fill, earthwork and the survey
      follow live.
- [ ] Ground can be excluded. Excluded ground keeps its terrain and carries no
      fill.
- [ ] The survey counts benched, excluded and wild lots separately.
- [ ] Authored elevations survive the terrain changing underneath them.

**Judged by leaving a hill.** Exclude a knoll, fill the suburb around it, and
look. If it reads as a park - ground the developer could not use - the model is
right. If it reads as a mesa with a hard edge, the margin needs a skirt and
that is Phase 1.

## Phase 1 - The edges

- [ ] **Does fill lap against an exclusion?** A hard edge reads as a mesa; real
      knolls have a skirt where the fill meets them.
- [ ] **Does a bench wrap an exclusion or stop at it?** Wrapping keeps streets
      continuous around a park; stopping makes the park a barrier, which is
      sometimes what a park is.
- [ ] Streets that meet an exclusion should end the way they end at a wash -
      the rule already exists, and this is the same rule applied inward.

## Phase 2 - The questions deferred

- [ ] **Handles or a painted field?** Handles match how benching already works
      and are fewer things to get wrong. A field is more expressive and much
      easier to make a mess with. Decide after a level has been authored both
      ways.
- [ ] **How is an exclusion bounded?** A drawn region is direct; "do not bench
      above this grade here" is more like the rest of the model and survives
      the terrain moving underneath it.
- [ ] **Whose 3D view?** Reusing the host's terrain rendering is less to build
      and couples the addon to whatever the host draws ground with. A view of
      the addon's own keeps it standalone and duplicates work.

## Phase 3 - Reconcile

- [ ] `AutomateBenchRules` currently derives every elevation. It needs to
      accept authored ones and solve around them, which is a change **upstream**
      in automate-godot rather than here.
- [ ] The survey's verdict lines assume two kinds of ground. A third changes
      what "100% buildable" means and probably what counts as a failure.
- [ ] The host's plan renderer decides where streets go. Exclusions have to
      reach it, or a level will draw streets across its own park.

---

## Sequencing note

**This is the second question, not the first.** Choosing a parcel stays planar
and stays on the map; the vertical is asked after the ground is chosen. Nothing
here should make siting a level harder for a project that never touches fill
height.

The risk worth naming: **authored elevations and a solver are a bad marriage if
neither wins.** If the solve can overwrite an authored bench, authoring is a
suggestion; if authored benches escape the riser cap, a level can be authored
into a cliff a street cannot climb. The rule that keeps both honest is that
authoring sets the target and the constraints still apply - and it needs stating
before the first handle is dragged, not after.
