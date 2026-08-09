# Assist level design, locally

## Why

The addon's premise is an opinionated AI workflow for building levels from real
topography at game scale. The workflow exists — region, window, survey, plan —
and the assistance does not.

It should be **local by default**, and that is a design decision rather than a
preference:

- **An API key is an adoption wall.** An Asset Library addon that cannot do its
  headline feature until a developer signs up somewhere is an addon most
  developers bounce off.
- **The loop is a nudge loop.** Drag the site, read the survey, drag again. A
  network round trip per nudge is friction in exactly the place the tool is
  supposed to be frictionless.
- **Unreleased levels are unreleased.** A designer's map should not have to
  leave their machine to be commented on.
- **It has to still work in five years.** A local model and a JSON schema will;
  a hosted endpoint's pricing and deprecation schedule will not.

## What the assistant is for, and what it must not touch

This is the part worth getting right, and today's work already settled it.

**It generates parameters and judgements. It does not generate ground.**

Asking an image model for terrain is the trap this addon exists to prevent. A
real fan runs 2.5 km with 150 m of relief and a board runs 204 m with 12:
gradient transfers at 1:1 and extent does not, so a generated heightmap comes
back either flat or alpine, and it comes back *plausible*, which is worse. A
model asked for "a valley" returns mountains, because that is what the word
means everywhere except here.

A model **is** good at filling a constrained schema and at reading numbers back
in prose. So:

| Assist | Not assist |
| --- | --- |
| Landform parameters from a description | Heightmap pixels |
| Reading a survey and saying what it means | Choosing the site |
| Naming streets, parks, neighbourhoods | Placing objects |
| Critiquing a plan against stated budgets | Deciding the budgets |

**Everything it returns is a proposal a designer accepts or discards**, and it
lands in fields that were already authorable by hand. Nothing the assistant
touches is a thing only it can touch.

## Structured output is what makes a small model reliable

The assistant asks for a **JSON schema fill**, never free prose that is then
parsed. Ollama constrains generation to a schema, so a 7B model returns a valid
`RegionLandform` because it is not being asked to be clever — it is being asked
to choose numbers inside stated bounds.

That is also what makes the failure mode safe: a schema fill that comes back
wrong is a bad *value*, visible immediately in the survey, rather than a
malformed response that breaks the tool.

## Which models to suggest

**Fully open source means the licence, not just the weights.** Several popular
"open" models ship under bespoke terms that are not OSI-approved, and an addon
recommending them without saying so is doing its users a disservice.

| Model | Licence | Why |
| --- | --- | --- |
| **OLMo 2** (Allen AI) | Apache 2.0 | Open weights **and** open training data. The most defensible "fully open source" answer |
| **Qwen 3** | Apache 2.0 | Strong structured output, several sizes, runs small |
| **Mistral / Mixtral** | Apache 2.0 | Well understood, widely packaged |
| **Phi-4** | MIT | Small, capable, the low-hardware option |
| *Gemma* | Gemma Terms of Use — **not OSI** | Capable; recommend only with the licence stated |
| *Llama* | Community Licence — **not OSI** | Same caveat |

The default suggestion should be a **small Apache-2.0 model**, because the job
is schema filling rather than reasoning, and a 7B model that runs on a laptop
does it. Recommending something that needs a 24 GB card would make the feature
theoretical for most of the people it is for.

**Ollama is the default host** — one install, an HTTP API, cross-platform, and
already how most developers run a model locally. `llama.cpp` for anyone
embedding, `vLLM` for anyone serving a team. Godot's own `HTTPRequest` reaches
all three, so the addon takes **no new dependency** to talk to any of them.

## What this does not do

- **It does not require a model.** Every existing feature works with the
  assistant absent, and the addon says so rather than failing.
- **It does not ship weights.** A model is installed by the developer.
- **It does not decide anything.** Proposals land in authorable fields.
- **It does not lock out hosted models.** The same schema-fill call works
  against any OpenAI-compatible endpoint; local is the default, not the cage.
- **It does not generate shipped assets.** Whatever it proposes is reference
  and blockout.

## Open questions

- **Does the assistant see the survey numbers, or the maps?** Numbers are
  cheap, precise, and work with a text model. Vision models could read the
  contour sheet the way a person does, at a large cost in hardware.
- **How is a proposal previewed before it is accepted?** A landform change
  redraws the whole region; showing before and after matters more than the
  proposal itself.
- **Is naming worth it?** It is the most obviously useful thing a small model
  does and the least important to the level.
- **Should the critique know the host's doctrine?** This addon knows about
  relief budgets and drainage; it does not know a project's own rules, and a
  critique that cannot see them will confidently miss the point.
