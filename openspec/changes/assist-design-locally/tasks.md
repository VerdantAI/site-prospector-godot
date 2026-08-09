## Tasks

The plan, 2026-08-09.

**Phase 0 is one call.** If a local model cannot reliably fill a
`RegionLandform` schema from a sentence, nothing else here is worth building,
and that is a morning's work to find out rather than a feature to commit to.

---

## Phase 0 - One schema, one model, one answer

- [ ] `AiAdvisor`: a resource with a host URL and a model name, talking over
      Godot's own `HTTPRequest`. No new dependency.
- [ ] One action: **describe the ground, get landform parameters.** Schema-
      constrained, bounded by the relief budget and the extent already declared.
- [ ] The proposal is shown against the current values before it is applied.
- [ ] Absent or unreachable model: everything still works, and the panel says
      why it is unavailable.

**Judged by whether a 7B model gets it right.** Ask for "a fan suburb below a
steep range front, three canyons, gentle lower fan" and see whether the numbers
that come back make a region worth prospecting. If a small model cannot, a
large one making it work is not a win - it would put the feature out of reach of
the people it is for.

## Phase 1 - Read the survey back

- [ ] **Critique a site**: hand it the survey and get prose that says what the
      numbers mean. This is the assist that needs no schema and cannot break
      anything.
- [ ] Check a proposal against the budgets rather than only reporting them.
- [ ] Naming: streets, parks, the neighbourhood. Cheap, obvious, and the least
      important thing here.

## Phase 2 - The questions deferred

- [ ] **Numbers or maps?** A text model reads the survey; a vision model could
      read the contour sheet the way a person does, at a large hardware cost.
      Worth testing once, not worth assuming.
- [ ] **Whose doctrine?** This addon knows about relief budgets and drainage. It
      does not know a host project's own rules, and a critique that cannot see
      them will confidently miss the point. A host-supplied brief may be the
      answer.
- [ ] Hosted endpoints, for anyone who wants one. The same schema-fill call
      works against an OpenAI-compatible API; local is the default, not the cage.

## Phase 3 - Documentation

- [ ] Suggested models **with licences**, distinguishing OSI-approved from
      bespoke open-weight terms. Default to a small Apache-2.0 model.
- [ ] The install path: Ollama, one pull, a URL in Project Settings.
- [ ] State plainly what the assistant will not do, because "AI level design"
      promises heightmap generation to most readers and this deliberately does
      not do that.

---

## Sequencing note

**The assistant is a convenience, and the moment it becomes load-bearing this
is a worse addon.** Every proposal lands in a field a designer could have typed,
so a project can ignore it, undo it, or never install it and lose only typing.
That constraint is what keeps the tool honest, and it is easier to hold now than
to reintroduce after something depends on it.

The risk worth naming: **a plausible wrong answer is the failure mode.** A model
returning terrain that is subtly out of scale is more expensive than one
returning nothing, because the mistake survives review and only shows up when
somebody walks the level. Bounding the schema is the guard; showing the survey
before accepting is the second one.
