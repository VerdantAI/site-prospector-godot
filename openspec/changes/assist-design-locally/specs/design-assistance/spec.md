# design-assistance

## ADDED Requirements

### Requirement: Assistance SHALL be optional and locally hosted by default

The addon SHALL function completely with no model available, and SHALL default
to a locally hosted one when assistance is used. A hosted service SHALL NOT be
required to use any feature.

An addon whose headline capability needs an account is one most developers
bounce off before finding out whether it is any good. The design loop is also a
nudge loop - drag, read, drag - and a network round trip per nudge is friction
in the place the tool exists to remove it. Local keeps unreleased levels on the
machine that made them, and keeps the feature working when an endpoint's
pricing changes.

#### Scenario: No model is installed

- **WHEN** a designer uses the addon with no model available
- **THEN** every existing feature works, and the assistant says it is
  unavailable rather than failing partway through an action

#### Scenario: A model is installed

- **WHEN** a local host is reachable
- **THEN** assistance is offered without any account, key or network access
  beyond that host

### Requirement: The assistant SHALL propose parameters, never terrain

Assistance SHALL be limited to values, names and judgements. It SHALL NOT
generate heightmaps, elevation data or object placements.

This is the mistake the addon exists to prevent. A real fan runs kilometres
with a hundred metres of relief and a board runs a few hundred metres with
twelve, so generated ground comes back flat or alpine - and plausible, which is
worse. Asked for "a valley" a model returns mountains, because that is what the
word means everywhere except here. Filling a bounded schema is a job a small
model does reliably; inventing ground at an unfamiliar scale is not.

#### Scenario: A designer describes the ground they want

- **WHEN** a description is given to the assistant
- **THEN** it returns landform *parameters* within their stated bounds, and the
  region is regenerated from them by the existing generator

#### Scenario: A proposal is out of bounds

- **GIVEN** a proposal whose relief exceeds the stated budget
- **THEN** it is reported against the budget rather than silently applied

### Requirement: Every proposal SHALL land in a field a designer could have set

An assistant's output SHALL be written only to parameters that are authorable
by hand, and SHALL be presented for acceptance rather than applied directly.

Nothing the assistant touches should be a thing only it can touch. That keeps
it a convenience rather than a dependency: a project can ignore it, undo it, or
never install it, and lose nothing but typing.

#### Scenario: A proposal is offered

- **WHEN** the assistant returns a proposal
- **THEN** the designer sees what would change and accepts or discards it, and
  discarding leaves the project as it was

#### Scenario: The assistant is removed later

- **WHEN** a project stops using assistance
- **THEN** everything it produced remains editable, because it was written to
  ordinary authored fields

### Requirement: Requests SHALL be schema-constrained

Assistance SHALL request output constrained to a declared JSON schema rather
than parsing free prose.

A schema fill is a job a 7B model does reliably, because it chooses values
inside stated bounds rather than being asked to be clever. It also makes the
failure mode safe: a bad answer is a bad *value*, visible in the survey the
moment it lands, rather than a malformed response that breaks the tool.

#### Scenario: A model returns an unusable answer

- **WHEN** a response does not satisfy the schema
- **THEN** the action reports that plainly and changes nothing

### Requirement: Suggested models SHALL state their licence

Documentation SHALL name suggested models with their licences, and SHALL
distinguish open-weight models under bespoke terms from those under an
OSI-approved licence.

"Open source" is widely used for weights published under terms that restrict
use, and an addon recommending them without saying so leaves its users to find
out later. The default suggestion should also be a model small enough to run on
a laptop, because the job is schema filling and recommending hardware most
users do not have makes the feature theoretical.

#### Scenario: A developer chooses a model

- **WHEN** the documentation suggests models
- **THEN** each carries its licence, and any that is not OSI-approved is marked
  as such

#### Scenario: Hardware is modest

- **WHEN** a developer follows the default suggestion
- **THEN** it is a model that runs on ordinary hardware rather than one needing
  a large accelerator
