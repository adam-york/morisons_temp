# Morison Toolbox — Domain Model Review and Proposal

Review of the WIP codebase (45 `.m` files) and a proposed replacement domain model.

*Revision 2 — incorporates review feedback: `AnalysisBand` → `HydrodynamicSegment`; member outer diameter moved off the marine growth definition; independent Cd/Cm maxima confirmed as intended behaviour; empty segments excluded from output.*

---

## 1. Review of the current architecture

### 1.1 What the code does today

```
process(attachments_table, marine_growth_table)
  validate_inputs                          6 free-standing rule checks
  split_attachments_by_marine_growth       cut attachment rows at MG boundaries
  repeat_rows_with_wave_angles(., 24)      24x row explosion
  calculate_table_iec_cd_cm                per row: look up MG at midpoint, evaluate IEC C.18/C.19
  summarise_table                          groupsummary sum by (lower, upper, angle), then max by (lower, upper)
  calculate_table_equivalent_hydro_props   per row: look up MG at midpoint again, combine with member
  excel_writer
```

Everything is a `table`. There are no types. Each stage's contract is a set of column names that exists only in comments.

### 1.2 Credit where due

The current code has clearly already been through one refactor aimed at the duplication problem, and the direction was right: marine growth values are deliberately *not* copied onto the attachment table, and are looked up fresh at each point of use. The IEC equations in `iec_hydrodynamics/` are cleanly factored, pure, and well tested. `calculate_equivalent_hydro_properties` is good code.

The problem is that the fix removed the *duplication* without removing the *coupling*. What replaced it is a hidden temporal dependency, which is harder to see and just as dangerous.

### 1.3 Design problems

**P1 — The central invariant is unowned.**

`calculate_row_iec_cd_cm` takes the row's midpoint elevation and looks up marine growth there. This is only correct because `split_attachments_by_marine_growth` ran earlier and guaranteed that every row lies wholly inside one marine growth zone. Nothing carries that guarantee. The split function returns a plain `table`, structurally indistinguishable from the `attachments_table` that went in — the test `keeps_attachment_columns_and_does_not_merge_marine_growth` asserts exactly this.

So:

- Call `calculate_table_iec_cd_cm(attachments_table, mg)` without splitting first and it runs silently, using whichever zone happens to contain each attachment's midpoint, ignoring the others.
- Insert a stage between split and calculate that adds or merges rows, and the same thing happens.
- Reorder the pipeline and there is no error, just wrong numbers.

This is the implicit assumption you want to eliminate. It is not really "marine growth properties are duplicated" — it is *"the reader of the data must remember something the data does not say."* Duplication was one symptom; the midpoint lookup is another symptom of the same cause.

**P2 — Association by repeated search rather than by resolution.**

The attachment↔marine-growth relationship is genuine domain knowledge, but it is never held anywhere. It is re-derived by `find_elevation_row_index` on every single evaluation — `n_attachments × n_zones × 24` times — each time producing the same answer. `calculate_row_equivalent_hydro_properties` then derives it a third time at the summary stage. A fact that is recomputed in three places is a fact that can be computed three different ways; note that it very nearly already is (see P4).

**P3 — Overlapping output rows (confirmed defect).**

`summarise_table` groups on `(lower_elevation, upper_elevation)`. Consider one marine growth zone spanning 0–20 m and two attachments:

| Attachment | Range |
|---|---|
| A | 0–10 |
| B | 5–15 |

Neither is split (both sit inside one zone). The groups are `(0,10)` and `(5,15)`, so the output profile is:

```
0 ──────────── 10        row 1: A only
      5 ──────────── 15   row 2: B only
```

Two overlapping output rows, and over 5–10 m — where A and B are physically both present — no row sums them. Whatever consumes this profile downstream sees an ambiguous, double-covered member. The bug is invisible today because the model has no concept of "the set of attachments present at this elevation"; it only has "rows that happen to share two numbers".

**P4 — Two inconsistent definitions of range membership.**

`split_attachments_by_marine_growth` uses `elevation_tolerance()` (1e-9) for overlap. `find_elevation_row_index` uses exact `<=` for containment. `check_elevations_are_contiguous` uses the tolerance again. Three call sites, two semantics. A row clipped exactly to a zone boundary is currently saved only by the midpoint being strictly interior — which is a coincidence of the algorithm, not a property anyone chose.

**P5 — Floating-point doubles as a grouping key.**

`groupsummary` on `(lower_elevation, upper_elevation)` relies on bit-exact equality of doubles that have been through `max`/`min` arithmetic in `clip_row_to_overlap`. It happens to work because the clip returns one of the two operands unmodified. It is not a property you want load-bearing. `rename_groupsummary_columns` doing string surgery on `sum_equivalent_cd` is a second fragility on the same seam.

**P6 — The wave-angle cross product is baked into the data.**

`repeat_rows_with_wave_angles` turns a loop inside out, creating a 24× table that exists only to be collapsed again by `get_worst_case_cd_cm`. Wave angle is an axis of *evaluation*, not an attribute of an attachment. Materialising it forces every downstream stage to be aware of it.

**P7 — Analysis parameters disguised as constants.**

`n_wave_dirs = 24` is a literal in `process.m`. `wave_spreading_factor = 1` is a literal buried inside `calculate_row_iec_cd_cm`, three levels down. Neither can be varied without editing source, and neither appears in the output for traceability.

**P8 — Validation carrying the model's weight.**

Five of the six checks in `validate_inputs` exist to prevent a lookup failing deep inside the calculation. They are a guard rail around a design that permits invalid states to be constructed. `check_marine_growth_covers_upper_range` in particular is answering "will the lookup I am about to do 4 stages from now succeed?" — a question a well-formed profile object would make unaskable.

**P9 — A domain assumption is riding on a shared struct field.**

In `calculate_equivalent_cd`, `attachment_mg_od = attachment_od + 2 .* mg_thickness` applies the marine growth thickness read for the *monopile* to the *attachment*. That may well be intended and correct, but it currently happens because both read the same field of the same struct, not because anyone declared "growth thickness in a zone applies to every cylinder in that zone".

**P10 — Independent maxima over wave angle.**

`get_worst_case_cd_cm` takes `max(cd)` and `max(cm)` separately, so the reported pair can come from two different headings and need not correspond to any single physical sea state. This is intended and conservative — see §4.1 — but it is currently an unremarked consequence of passing two value columns to `groupsummary`, with nothing in the code saying so.

**P11 — File-per-function sprawl.**

45 files, of which `calculate_wave_angles`, `calculate_relative_wave_angle`, `calculate_midpoint_elevation` and `elevation_tolerance` are one-liners with a single caller each. This runs against your own stated preference for local helpers.

**P12 — Pure geometry stored as a growth property.**

`marine_growth_table` carries four columns: `marine_growth_thickness`, `mp_drag_coeff`, `mp_inertia_coeff` — and `mp_outer_diameter`. The first three are legitimately growth-related: thickness *is* the growth, and the drag and inertia coefficients are the member's coefficients *in its grown state* (Cd in particular is a function of relative surface roughness, which is a growth property). The monopile's clean-steel outer diameter is not. It is fixed geometry that varies with elevation for structural reasons entirely unrelated to marine growth, and it appears in this table only because the marine growth table was the only elevation-banded input available to put it in.

The consequence is that `MemberOuterDiameter` reads as something marine growth determines, and any future change to the growth banding silently re-bands the member geometry with it.

*Note: revision 1 of this document carried this grouping straight across into the proposed `MarineGrowth` class. That was a mistake — mirroring the legacy input schema instead of modelling the domain. Corrected in §2.3 below.*

### 1.4 On your proposed starting point

`Structure` / `Attachment` / `MarineGrowthDefinition` is the right instinct — it correctly identifies that an attachment and a marine growth definition are peers, each owning an elevation range, neither owning the other. You already spotted why it stops short: nothing in it represents *a portion of an attachment under uniform conditions*, so the segmentation logic has nowhere to live and ends up back in a procedure.

The missing concept is not on the attachment side. It is the segment itself.

---

## 2. Proposed model

### 2.1 The core idea

> Partition the member into **hydrodynamic segments** at **every** boundary — marine growth *and* attachment. Within one segment, conditions are constant by construction: exactly one set of marine growth properties, and a fixed set of attachments present over the segment's full height.

A segment is not a row that was cut. It is a region of uniform hydrodynamic conditions, and it is the natural unit of calculation, of grouping, and of output. Because segments come from the common refinement of all boundaries, they are non-overlapping by construction, which resolves P3 without a validation rule.

Marine growth is not duplicated onto attachments; it is resolved *once*, when the segment is created, and after that no code in the system performs an elevation lookup.

### 2.2 Type diagram

```
Structure ────────────────────────► MarineGrowthProfile
   │  Attachments : Attachment[]      │  Zones : MarineGrowthZone[]
   │  Growth      : MarineGrowthProfile│
   │                                  MarineGrowthZone
   │  hydrodynamicSegments() ─┐       │  Range  : ElevationRange
   │                          │       │  Growth : MarineGrowth
   ▼                          │
Attachment                    │       MarineGrowth
   Range : ElevationRange      │        Thickness
   MemberOuterDiameter  ◄──────┼──┐     MemberDragCoefficient
   OuterDiameter               │  │     MemberInertiaCoefficient
   CentreToCentreDistance      │  │
   Angle                       │  │    (no geometry — growth state only)
   Quantity                    │  │
   Name                        │  │
                               │  │
                               ▼  │
                    HydrodynamicSegment ◄──── the pivotal type
                       Range               : ElevationRange
                       Growth              : MarineGrowth   (exactly one — not a lookup)
                       Attachments         : Attachment[]   (each spans Range fully, >= 1)
                       MemberOuterDiameter : double  ────────┘  (derived, agreed)
                          │
                          │  analyseSegment(segment, settings)
                          ▼
                    SegmentResult
                       Range, EquivalentCd, EquivalentCm,
                       AdditionalThickness, CdD,
                       Contributions : AttachmentContribution[]
```

Every class is a value class (`classdef` with no `< handle`). All properties are `SetAccess = immutable`, set once in the constructor.

### 2.3 Class specifications

---

#### `ElevationRange`

The workhorse value type. Absorbs `calculate_midpoint_elevation`, `elevation_tolerance`, `check_elevations_are_ordered`, and the ad-hoc comparisons scattered across `split_attachments_by_marine_growth` and `find_elevation_row_index`.

```matlab
properties (SetAccess = immutable)
    Lower  (1,1) double
    Upper  (1,1) double
end
properties (Constant)
    Tolerance = 1e-9      % single definition, used by every comparison
end

methods
    obj = ElevationRange(lower, upper)   % errors unless upper > lower + Tolerance
    m   = midpoint(obj)
    h   = height(obj)
    tf  = contains(obj, elevation)
    tf  = spans(obj, other)              % other lies wholly within obj
    tf  = overlaps(obj, other)           % strict overlap, tolerance-aware
    r   = intersect(obj, other)
end

methods (Static)
    ranges = fromBoundaries(boundaries)  % sorted+uniquetol edges -> consecutive ranges
end
```

Notes:

- A `1×N` array of `ElevationRange` is the natural representation of a profile. MATLAB value-class arrays work fine here; construct with `arrayfun(..., 'UniformOutput', false)` then `[c{:}]`.
- One `Tolerance` constant, used by `contains`, `spans`, `overlaps` and `fromBoundaries` alike. Fixes **P4**.
- `lower >= upper` is unconstructible. `check_elevations_are_ordered` deleted.

---

#### `MarineGrowth`

The growth *state* — and nothing else. Deliberately holds no elevation (that is what separates "what the conditions are" from "where they apply", and it is what makes the properties shareable without being duplicated) and no geometry (**P12**).

```matlab
properties (SetAccess = immutable)
    Thickness                (1,1) double
    MemberDragCoefficient    (1,1) double
    MemberInertiaCoefficient (1,1) double
end
```

Every remaining field is genuinely growth-determined:

- `Thickness` — the growth itself. Applies to **every cylinder in the segment**, member and attachments alike; this is the assumption previously riding on a shared struct field (**P9**), now stated by the type at the one place the value lives.
- `MemberDragCoefficient` / `MemberInertiaCoefficient` — the member's nominal coefficients *in its grown state*. Cd is a function of relative surface roughness, so these belong with the growth definition rather than with the geometry.

`MemberOuterDiameter` has moved to `Attachment` — see below.

---

#### `MarineGrowthZone`

```matlab
properties (SetAccess = immutable)
    Range  (1,1) ElevationRange
    Growth (1,1) MarineGrowth
end
```

A trivial pairing, but it is what lets `MarineGrowth` stay elevation-free. The name *zone* is kept deliberately distinct from *segment*: a marine growth zone is an input band; a hydrodynamic segment is a derived band. Keeping the words apart makes the refinement step readable.

---

#### `MarineGrowthProfile`

```matlab
properties (SetAccess = immutable)
    Zones (1,:) MarineGrowthZone     % sorted ascending, contiguous, non-overlapping
end

methods
    obj    = MarineGrowthProfile(zones)   % sorts, then validates in the constructor
    g      = at(obj, elevation)           % -> MarineGrowth, errors if uncovered
    r      = span(obj)                    % -> ElevationRange covering all zones
    edges  = boundaries(obj)              % -> sorted unique elevations
end
```

The constructor performs the sort and runs the contiguity / no-overlap checks **once**. After that, a `MarineGrowthProfile` that exists is a valid one. `check_elevations_are_contiguous` and `check_elevations_have_no_overlaps` become private local functions in this file — they keep their unit tests, they simply stop being public API.

Crucially, `at()` has exactly one caller in the whole system: `Structure.segmentFor`. Everything else receives a resolved `MarineGrowth`. This is what kills **P2**.

---

#### `Attachment`

```matlab
properties (SetAccess = immutable)
    Name                   (1,1) string
    Range                  (1,1) ElevationRange
    MemberOuterDiameter    (1,1) double   % clean-steel OD of the member it is mounted on
    OuterDiameter          (1,1) double
    CentreToCentreDistance (1,1) double   % member axis to attachment axis
    Angle                  (1,1) double   % deg, structure-referenced
    Quantity               (1,1) double
end

methods
    a = relativeWaveAngle(obj, waveAngle)   % mod(waveAngle - obj.Angle, 360)
end
```

No marine growth data. No elevation numbers loose on the object — `Range` owns them.

**On `MemberOuterDiameter` living here.** It sits naturally alongside `CentreToCentreDistance`, which is already measured *from the member axis*: both describe the attachment's geometric relationship to the member it is mounted on, and both are consumed together by `calculate_potential_flow_factor` and `calculate_fitting_function`. Grouping them makes the IEC equation inputs come from one coherent place rather than two unrelated tables.

The trade-off, stated plainly: the member OD is now potentially multi-valued within a segment — two attachments at the same elevation could disagree. That is handled as a construction invariant on `HydrodynamicSegment` (below), which is the same mechanism the model already uses for profile contiguity, so it is consistent rather than a special case. If member geometry ever needs to vary independently of both attachments and growth — a tapered or stepped monopile with no attachments on some sections — the fully structural answer is a third elevation-banded input, `MemberProfile`, contributing its own boundaries to the refinement. That is a strictly larger change and is not proposed now; it is noted as the escape hatch.

> **Input schema change.** `mp_outer_diameter` moves out of the marine growth input sheet and into the attachments input sheet. This affects the Excel input workbook, not just the code.

---

#### `Structure`

The composition root, and the only place the attachment↔growth association is ever resolved.

```matlab
properties (SetAccess = immutable)
    Attachments (1,:) Attachment
    Growth      (1,1) MarineGrowthProfile
end

methods
    obj      = Structure(attachments, growth)   % errors unless Growth.span spans every attachment
    segments = hydrodynamicSegments(obj)        % -> (1,:) HydrodynamicSegment
end
```

The constructor absorbs `check_marine_growth_covers_upper_range` / `..._lower_range` — but now as a genuine construction invariant rather than a pre-flight check for a lookup four stages downstream (**P8**). `validate_inputs.m` disappears entirely; its six rules are distributed to the three constructors that can actually guarantee them.

`hydrodynamicSegments` is the heart of the model:

```matlab
function segments = hydrodynamicSegments(obj)
    edges  = allBoundaries(obj);                       % local helper
    ranges = ElevationRange.fromBoundaries(edges);
    ranges = ranges(arrayfun(@(r) obj.hasAttachmentsOver(r), ranges));   % drop empty
    segments = arrayfun(@(r) obj.segmentFor(r), ranges);
end

% local, private to Structure.m
function edges = allBoundaries(obj)
    edges = [ obj.Growth.boundaries(), ...
              arrayfun(@(a) a.Range.Lower, obj.Attachments), ...
              arrayfun(@(a) a.Range.Upper, obj.Attachments) ];
    edges = edges(edges >= profileLow & edges <= profileHigh);   % clip to profile span
    edges = uniquetol(sort(edges), ElevationRange.Tolerance, 'DataScale', 1);
end

function segment = segmentFor(obj, range)
    growth  = obj.Growth.at(range.midpoint());
    present = obj.Attachments(arrayfun(@(a) a.Range.spans(range), obj.Attachments));
    segment = HydrodynamicSegment(range, growth, present);
end
```

Three things to note.

*Why the midpoint is safe here and was not safe before.* Because `edges` includes every marine growth boundary, no candidate `range` can straddle a zone. That is now guaranteed at the point of use, three lines away, by the function that built the ranges — not by a different function that ran four stages earlier and left no trace. Same technique, entirely different coupling.

*Why `spans` and not `overlaps`.* Because `edges` also includes every attachment boundary, an attachment either covers a range completely or misses it completely; partial overlap is arithmetically impossible. `spans` therefore states the stronger, true condition and will fail loudly if the refinement is ever broken. This is the fix for **P3**: the region 5–10 in the earlier example is now its own segment, containing both A and B.

*Why empty ranges are dropped before construction, not filtered in reporting.* A range with no attachments has no member outer diameter — the value now comes from the attachments — so such a segment is not merely uninteresting, it is unconstructible. Filtering at the point of creation states that directly. The output profile may therefore contain gaps where nothing is mounted; it will never contain overlaps.

---

#### `HydrodynamicSegment`

The type that makes the assumption you want to eliminate unrepresentable.

```matlab
properties (SetAccess = immutable)
    Range               (1,1) ElevationRange
    Growth              (1,1) MarineGrowth   % exactly one, by cardinality
    Attachments         (1,:) Attachment     % at least one
    MemberOuterDiameter (1,1) double         % derived in the constructor
end

methods
    obj = HydrodynamicSegment(range, growth, attachments)
        % validates: attachments non-empty
        %            every attachment.Range spans range
        %            all attachments agree on MemberOuterDiameter (to ElevationRange.Tolerance)
        % derives:   MemberOuterDiameter = attachments(1).MemberOuterDiameter
end
```

`Growth (1,1)` is doing the real work. It is not possible to construct a segment with two sets of marine growth properties, or with none, or with properties that disagree with the segment's elevation — there is no elevation on `MarineGrowth` to disagree with. The assumption is gone because the shape of the type cannot express its violation.

`MemberOuterDiameter` is resolved once here and exposed as a single scalar, so every downstream consumer sees one agreed value and no code below this point needs to know that it originated on the attachments.

**On restricting construction.** MATLAB can restrict the constructor with `methods (Access = ?Structure)`, which would make `Structure` the sole factory. I recommend **against** it: it blocks tests from building segments directly, and the invariant is better enforced by the constructor validating itself (which it does anyway) than by policing who may call it. A self-validating public constructor is safe regardless of caller *and* testable. Prefer that.

---

#### `AnalysisSettings`

```matlab
properties (SetAccess = immutable)
    WaveDirectionCount  (1,1) double = 24
    WaveSpreadingFactor (1,1) double = 1
end
methods
    angles = waveAngles(obj)   % (0:n-1)' * 360/n
end
```

Fixes **P7**. Both magic numbers become named, defaulted, overridable, and reportable. `calculate_wave_angles` becomes a method on the object that owns the count.

---

#### `AttachmentContribution` and `SegmentResult`

```matlab
% AttachmentContribution — one attachment at one heading, for reporting
properties (SetAccess = immutable)
    AttachmentName (1,1) string
    WaveAngle      (1,1) double
    Cd             (1,1) double   % quantity-weighted
    Cm             (1,1) double
end

% SegmentResult
properties (SetAccess = immutable)
    Range               (1,1) ElevationRange
    EquivalentCd        (1,1) double   % attachments only, worst case over heading
    EquivalentCm        (1,1) double   % worst case taken INDEPENDENTLY of Cd — see analyseSegment
    AdditionalThickness (1,1) double   % member + attachments combined
    CdD                 (1,1) double
    Contributions       (1,:) AttachmentContribution
end
```

`Contributions` preserves the per-attachment, per-heading detail currently exported as the `attachment_calculation` sheet. It is retained for reporting only — nothing calculates from it.

---

### 2.4 File layout

Use a package folder so the names are namespaced and `import morison.*` is available:

```
+morison/
    ElevationRange.m           MarineGrowth.m
    MarineGrowthZone.m         MarineGrowthProfile.m    (+ contiguity/overlap local fns)
    Attachment.m               Structure.m              (+ refinement local fns)
    HydrodynamicSegment.m      AnalysisSettings.m
    AttachmentContribution.m   SegmentResult.m
    analyseSegment.m           (+ all per-segment calculation local fns)
    reportTables.m             (+ per-sheet local fns)
iec_hydrodynamics/             UNCHANGED — 6 files, already clean and tested
excel_writer.m                 UNCHANGED
process.m                      rewritten, ~15 lines
tests/
```

**45 files → ~16.** MATLAB requires one `classdef` per file, so the classes are irreducible; everything else collapses into local functions in the file that owns the behaviour, per your stated preference (**P11**).

Deleted or absorbed:

| Gone | Absorbed into |
|---|---|
| `elevation_lookup/` (4 files) | `ElevationRange`, `MarineGrowthProfile.at` |
| `validation/` (6 files) | the three constructors that can guarantee the rules |
| `table_preparation/` (4 files) | `Structure.hydrodynamicSegments`, `AnalysisSettings`, `Attachment` |
| `results_summary/` (5 files) | `analyseSegment` (no grouping needed — segments are objects) |
| `cd_cm_calculation/` (2 files) | `analyseSegment` |
| `hydro_properties/` table+row wrappers (2 of 3) | `analyseSegment` |

The whole of `results_summary/` disappearing is the clearest signal the model is right: five files of `groupsummary` plumbing and column-name string surgery existed solely to reconstruct a grouping that the new model never dissolves in the first place. **P5** goes with them.

---

## 3. How attachments and marine growth interact

The relationship is resolved exactly once, in `Structure.segmentFor`, and never again.

| | Today | Proposed |
|---|---|---|
| Where resolved | 3 places (`split_...`, `calculate_row_iec_cd_cm`, `calculate_row_equivalent_hydro_properties`) | 1 place (`Structure.segmentFor`) |
| How often | `n_att × n_zones × 24` + `n_rows` searches | once per segment |
| Correctness rests on | remembering to split first | the cardinality of `HydrodynamicSegment.Growth` |
| Failure mode | silent wrong answer | unconstructible |

Neither party knows about the other. `Attachment` has no growth field; `MarineGrowth` has no elevation and no geometry, let alone an attachment list. They meet only inside a segment, which is created by the one object that holds both — `Structure`. That is composition doing the work that duplication and lookup were doing before.

**Is holding `Growth` on each segment a new duplication?** Two adjacent segments inside the same zone hold equal `MarineGrowth` values. This is not the failure mode you are guarding against, for three reasons: the values are derived from a single source at a single moment; the objects are immutable, so they cannot drift; and segments are never merged, split, or regrouped after construction, so there is no operation during which they could fall out of step. The alternative — storing a zone index and re-dereferencing — reintroduces exactly the indirection the model is trying to remove, and would mean passing the profile everywhere. Hold the value.

---

## 4. The workflow

```matlab
function process(attachmentsTable, marineGrowthTable, settings)
    arguments
        attachmentsTable   table
        marineGrowthTable  table
        settings (1,1) morison.AnalysisSettings = morison.AnalysisSettings()
    end
    import morison.*

    structure = buildStructure(attachmentsTable, marineGrowthTable);   % local: table -> objects
    segments  = structure.hydrodynamicSegments();
    results   = arrayfun(@(s) analyseSegment(s, settings), segments);

    excel_writer(reportTables(results, settings), outputPath());
end
```

Five lines of domain logic. Compare with the current `process.m`, where four of the seven steps exist to establish or repair invariants.

`analyseSegment` — the single unit of calculation, pure, one file, local helpers:

```matlab
function result = analyseSegment(segment, settings)
% Pure: SegmentResult is a total function of (segment, settings). No lookups,
% no ambient state, no ordering dependency on any other segment.
    import morison.*

    angles        = settings.waveAngles();
    contributions = attachmentContributions(segment, angles, settings);
    [cd, cm]      = worstCaseOverHeading(contributions, angles);

    [thickness, cdD] = calculate_equivalent_hydro_properties( ...
        segment.MemberOuterDiameter, segment.Growth.Thickness, ...
        segment.Growth.MemberInertiaCoefficient, segment.Growth.MemberDragCoefficient, ...
        cm, cd);

    result = SegmentResult(segment.Range, cd, cm, thickness, cdD, contributions);
end
```

with local helpers, none of which is worth its own file:

- `attachmentContributions(segment, angles, settings)` — nested loop over `segment.Attachments × angles`, calling the existing `calculate_equivalent_cd` / `calculate_equivalent_cm` with `attachment.MemberOuterDiameter`, `segment.Growth.Thickness`, and `attachment.relativeWaveAngle(angle)`; multiplies each by `attachment.Quantity`; returns `AttachmentContribution[]`.
- `worstCaseOverHeading(contributions, angles)` — see below. Wave angle exists only inside these two functions (**P6** — no 24× table is ever materialised).

Note `analyseSegment` receives `segment.Growth` as a resolved object and `segment.MemberOuterDiameter` as a resolved scalar. There is no `marine_growth_table` parameter anywhere below `Structure`. Compare the current `calculate_table_iec_cd_cm(inputs_table, marine_growth_table)` → `calculate_row_iec_cd_cm(row, marine_growth_table)`: the table is threaded three levels deep purely so a lookup can happen at the bottom.

`reportTables(results, settings)` flattens the object graph into the same three sheets you export today. **Tables become an output format, not the working data structure** — which is the single change that removes the possibility of a summarisation step misaligning anything, because by the time a table exists, all calculation is finished.

### 4.1 Worst case over heading — Cd and Cm are maximised independently

This is deliberate, and it is the behaviour the current `get_worst_case_cd_cm` already has. The new model makes it a named function with the reasoning attached, rather than an unremarked consequence of passing two value columns to `groupsummary` (**P10**):

```matlab
function [cd, cm] = worstCaseOverHeading(contributions, angles)
% Sum each heading's attachment contributions, then take the largest Cd and
% the largest Cm across headings.
%
% NOTE: the maxima are taken INDEPENDENTLY. The returned Cd and Cm may come
% from two different wave headings and need not correspond to any single
% physical sea state. This is intentional: drag and inertia peak at different
% headings, and the design case must envelope both. Pairing them to a common
% heading would be non-conservative. Do not "fix" this by selecting the
% heading that maximises Cd and reading Cm from it.

    cdPerAngle = arrayfun(@(a) sum([contributions([contributions.WaveAngle] == a).Cd]), angles);
    cmPerAngle = arrayfun(@(a) sum([contributions([contributions.WaveAngle] == a).Cm]), angles);

    cd = max(cdPerAngle);
    cm = max(cmPerAngle);
end
```

The comment is the point. This is a decision that looks like a bug to the next reader, and the codebase should say so in the one place it happens.

### 4.2 Empty segments

Segments with no attachments are not constructed and not reported (§2.3, `Structure.hydrodynamicSegments`). The reported profile is therefore non-overlapping but not necessarily contiguous: elevations with no attachments simply do not appear. Any downstream consumer that needs a gap-free member profile is responsible for treating absent elevations as bare member.

---

## 5. Testability

The model is easier to test than the current code in a specific way: **every unit under test can be constructed directly, in one line, with no pipeline setup.**

| Test | Setup |
|---|---|
| `analyseSegment` | build one `HydrodynamicSegment` literal; assert `SegmentResult` |
| Segment refinement | build a `Structure`; assert segment ranges and per-segment attachment sets |
| Overlapping attachments (**P3** regression) | two overlapping attachments, one zone → assert 3 segments, middle one containing both |
| Empty segments excluded | attachments at 0–5 and 10–15 → assert 2 segments, none covering 5–10 |
| Member OD disagreement | two attachments over the same range with different `MemberOuterDiameter` → assert constructor error |
| Profile validation | assert `MarineGrowthProfile` constructor errors on a gap |
| Independent maxima (§4.1) | contributions peaking at different headings → assert Cd and Cm come from different angles |
| Range algebra | pure, exhaustive, no fixtures |

Compare `TestCalculateRowIecCdCm` today, which must hand-build a `table` with six specific columns and a second `table` with six more, and whose two cases are *both* really testing the elevation lookup rather than the calculation. Under the proposal, the lookup is tested once against `MarineGrowthProfile`, and `analyseSegment` is tested against the physics.

**Existing tests, disposition:**

- Keep unchanged: all `iec_hydrodynamics` tests, `TestCalculateRowEquivalentHydroProperties` (retarget to `analyseSegment`).
- Keep, retarget: `TestCheckElevationsAreContiguous` → `MarineGrowthProfile` constructor. `TestCalculateWaveAngles` → `AnalysisSettings.waveAngles`. `TestCalculateRelativeWaveAngle` → `Attachment.relativeWaveAngle`. `TestCalculateMidpointElevation` → `ElevationRange.midpoint`.
- Replaced: `TestSplitAttachmentsByMarineGrowth` → segment refinement tests (broader: also covers attachment boundaries). `TestFindElevationRowIndex` + `TestGetValueByElevation` + `TestLookupMarineGrowthProperties` → one `MarineGrowthProfile.at` test.
- Deleted: `TestCombineCdCmByGroup`, `TestMultiplyCoefficientsByAttachmentQuantity` — the grouping machinery they cover no longer exists.

---

## 6. Design goals check

| Goal | How it is met |
|---|---|
| Value classes over handles | All 10 classes are value classes with `SetAccess = immutable`. No shared mutable state, no aliasing; `arrayfun` over segments is naturally independent. |
| Model over validation | 6 validation files → 3 constructor invariants. Invalid states are unconstructible rather than detected. |
| Performance not important | Segments are built eagerly and `arrayfun`'d; value-class copying is accepted freely. |
| Simple | 10 small classes, no inheritance, no interfaces, no patterns. The largest method is ~10 lines. |
| Composition over inheritance | Zero inheritance. `Structure` composes attachments + profile; `HydrodynamicSegment` composes a range + growth + attachments. |
| Testable calculations | `analyseSegment` is a pure function of two immutable values. |
| Few files, local helpers | 45 → ~16; refinement, contiguity, grouping and reporting helpers are all local to the file that owns the behaviour. |
| Don't minimise refactoring | Six directories are deleted, and the input workbook schema changes. `iec_hydrodynamics/` and `excel_writer.m` survive untouched — they were already right. |

---

## 7. Suggested order of work

1. `ElevationRange` + tests. Everything depends on it; it is pure and quick.
2. `MarineGrowth`, `MarineGrowthZone`, `MarineGrowthProfile` + constructor validation tests (port `TestCheckElevationsAreContiguous`).
3. `Attachment`, `Structure`, `HydrodynamicSegment`, and the refinement. **Write the overlapping-attachment regression test here** — it is the first point at which the P3 fix is demonstrable. Also covers empty-segment exclusion and member-OD agreement.
4. `AnalysisSettings`, `AttachmentContribution`, `SegmentResult`, `analyseSegment`. Reuse `iec_hydrodynamics/` unchanged.
5. `reportTables` + rewrite `process.m`.
6. Move `mp_outer_diameter` from the marine growth sheet to the attachments sheet in the input workbook.

### Expected differences vs. the current pipeline

For manual verification. Running old and new on the same inputs should differ in exactly three places, and nowhere else:

- **Where attachment ranges overlap within a marine growth zone** — the P3 fix. New output has more, finer, non-overlapping rows; the overlap region now sums both attachments. This is the only difference that changes a number that was previously reported.
- **Elevations with no attachments** — previously absent from the output as an accident of the row-splitting; now absent by design. No change in practice.
- **Row count and ordering** — segments are emitted in ascending elevation order rather than `groupsummary`'s sort order.

Anything else differing is a porting error, not the refactor.
