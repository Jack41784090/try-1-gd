# Refactor Plan — Unified AnimationTree Animation (face + body, compose-from-parts)

> Status: **plan only, no code changes yet.** Goal: drive every animation — face and body —
> through one `AnimationTree`, composing complex states ("crying") from small per-part clips
> instead of authoring monolithic animations. Signals still announce intent; the tree blends.

## 0. Locked decisions

- **Entry:** spike one face part first, before touching the live delta system.
- **Face format:** replace `FaceReaction` deltas entirely with hand-authored `Animation` clips.
- **Art:** single texture set deformed by transforms; a few texture-swap variants only where
  transforms fail (mouth shapes, closed eyes).

## 1. Current state (as-is)

**Body — already on AnimationTree, but only a state machine.** `warrior_rig_2.tscn`'s graph is
just `output → BodyStateMachine` (idle/walk/attack/defend/hurt/die/talk/gesture). One behavior
at a time. **No additive layers** — "hunch + arms_cover on top of idle" is not yet possible.
Body clips are hand-authored `Animation` subresources in `AnimationLibrary_main`
(`idle_body`, `walk_body`, `attack_swing_body`, ...) keyframing `Bone2D` properties via tracks
like `Skeleton2D/Root/Hips/Torso:rotation`. `WarriorAnimController.play_behavior()` travels the
state machine.

**Face — signal-driven deltas, not AnimationTree at all.** `Face.express(intent)` emits
`expression_changed`; each `FaceComponent` (Sprite2D) applies its own `position/rotation/scale`
deltas + optional texture swap via Tween, from an authored `FaceReaction` list. Live in
production cutscenes (EXPRESSION instructions). Procedural reactions live in
`tools/author_face_reactions.gd`.

**Historical scar:** a previous attempt put the face in the AnimationTree. The bake tool still
carries the cleanup — `DEAD_ANIM_NODES = ["OutputAdd", "FaceBlend", "EyeAnim", "MouthAnim"]`,
`DEAD_ANIMATIONS = ["eyes_neutral", "mouth_neutral"]`. Legacy `warrior_rig.tscn` still has that
old graph (`output → OutputAdd → BodyStateMachine + FaceBlend(EyeAnim, MouthAnim)`). This plan
revisits that idea, done properly with per-part layers instead of the crude two-node version.

## 2. Target architecture (to-be)

One `AnimationTree` drives everything. **Signals still announce intent** (`Face.express`,
`play_behavior`); a controller translates intent into AnimationTree parameters. Complex states
are *composed* from small per-part clips layered together — never authored as one animation.

**Key simplification:** face parts are *separate nodes* (BrowL ≠ Mouth). Clips touching disjoint
nodes compose without additive math — playing `brows_sad` and `mouth_smile` simultaneously just
works, because they write to different properties. Body parts share a skeleton, so body layering
uses standard `AnimationNodeAdd2` additive blending.

```
                      ┌─ BodyStateMachine (idle/walk/attack/...)  [existing]
output ← BodyAdd ─────┤
                      └─ BodyPoseAdd (hunch, arms_cover, ...)      [NEW: additive layers]

Face parts: per-part clip selection, crossfaded independently, composed
because they target disjoint Sprite2D nodes.                             [NEW]
```

**The one real tradeoff:** the delta system is *data-driven* (any intent → any per-part
response, trivially). AnimationTree is *more rigid per-part* (fixed graph inputs) but gives
smooth blending, independent layering, and face/body unification. The "expression recipe"
(intent → sparse `{part: clip}` table) replaces the distributed per-component reactions with a
centralized mapping; unlisted parts stay put, preserving "a part that doesn't answer stays
neutral."

## 3. Phases

### Phase 0 — Spike: one face part on the AnimationTree *(de-risk, do first)*
Empirically answer the Godot-blend questions before committing, on a throwaway branch.

- Pick **Brows** (BrowL/BrowR). Hand-author 2 clips in `AnimationLibrary_main`: `brows_neutral`
  (keys at baseline) and `brows_sad` (keys at baseline+tilt).
- Wire a minimal graph: `output ← Blend2(brows_neutral, brows_sad)`, drive `blend_amount` from code.
- **Answer concretely** (write findings down — they shape Phase 2):
  1. Does `Blend2` between two clips that key the *same* Sprite2D nodes crossfade smoothly?
  2. When two clips key *disjoint* nodes, do they compose correctly through the tree, or does the
     tree zero out tracks a clip doesn't contain? (Determines whether face needs `Add2` or just
     parallel leaves.)
  3. Does RESET need the face part tracks added (like body) to avoid the "invisible/collapsed"
     bug the bake tool already documents?
- **Verify:** scrub/blend in editor; a code toggle flips neutral↔sad with a visible smooth transition.
- **Risk:** this is where we learn if the approach is clean or fights the engine. Cheap to find out here.

### Phase 1 — Body additive layers *(additive, safe, parallelizable with Phase 2)*
"hunch + arms_cover on top of idle/walk" for the body.

- Author **additive** body clips keyframing only their bones: `hunch_over` (spine/Torso),
  `arms_cover_face` (arms/hands). Authored as deltas from rest pose.
- Extend `AnimTreeRoot`: `output ← BodyAdd(BodyStateMachine, BodyPoseAdd(...))`. Expose an
  `add_amount` per layer as a tree parameter.
- `WarriorAnimController`: add `set_body_layer(name, amount)` alongside existing `play_behavior`.
- Bake tool: ensure `_rebuild_reset` picks up the new tracks (it already scans all driven paths —
  likely just works).
- **Verify:** `animation_test.tscn` — toggle hunch/arms while walking; layers add on top without
  breaking locomotion. Existing behaviors unchanged.
- **Files:** `warrior_rig_2.tscn` (graph + clips), `warrior_anim_controller.gd`, possibly `bake_rig_scene.gd`.

### Phase 2 — Face on AnimationTree *(the migration; depends on Phase 0 findings)*
Replace the delta system with per-part clips + independent crossfades.

- **Clips:** hand-author per-part clips (`brows_sad`, `eyes_wide`, `mouth_smile`, `mouth_open`,
  `eyes_closed`, ...) as `Animation` subresources keyframing the face `Sprite2D` transforms at
  **absolute** target values (not deltas — see §5). Each clip keys ONLY its own part's nodes.
  Escape-hatch clips (mouth shapes, closed eyes) include a `texture`/`frame` track. Also author a
  `*_neutral` clip per part (baseline transform) as the Blend2's other input.
- **Graph:** the shape validated in §5 — per-part `Blend2(<part>_neutral, <part>_express)` for
  crossfade, `Add2`-merge the disjoint per-part outputs, then `Add2` the face onto the body state
  machine. One `blend_amount` parameter per part gives independent control.
- **Controller:** new `FaceAnimController` maps an **expression recipe** (intent → sparse
  `{part: clip}` table) to tree parameters. Unlisted parts stay put.
- **Delete:** `FaceReaction` (`face_reaction.gd`), the `reactions` array + `_on_expression_changed`
  tween logic in `face_component.gd`, and `tools/author_face_reactions.gd`. `Face.express()` keeps
  its signal; the controller listens instead of the components.
- **Migrate callers:** `WarriorRig.set_expression_by_name`, the `animation_test.gd` `E`-key cycle,
  and cutscene EXPRESSION instructions all keep working (they call `face.express(intent)` —
  unchanged surface).
- **Verify:** `face_component_test.tscn` assertions rewritten for the new mechanism;
  `animation_test.tscn` cycles expressions with smooth transitions; replay a cutscene (parliament)
  to confirm no regression.
- **Files:** `src/animation/face/*`, `warrior_rig_2.tscn`, new `FaceAnimController`, demos/tests.

### Phase 3 — Art pipeline → single texture set
Stop relying on per-emotion SVG variants; deform one part set.

- `export_face_features.py`: default to emitting **one neutral art per part**; only escape-hatch
  parts (mouth, closed-eye) keep emotion sub-groups.
- `bake_rig_scene.gd` face rebuild: stamp the single part set; escape-hatch variants become
  texture-swap tracks on the relevant clips rather than separate baked states.
- Keep the pipeline *capable* of variants (don't rip out the machinery) — just stop using them by default.
- **Verify:** rebake rachelle; face still renders; expressions now come from transforms.

### Phase 4 — Unify + cleanup
- Confirm face + body live in the one `AnimTree` graph; remove the last `DEAD_ANIM_NODES`/
  `DEAD_ANIMATIONS` scar handling once nothing references it.
- Remove stray `blink`/`new_animation` subresources if obsolete.
- Update `CLAUDE.md` (Animation System section), `.github/` instructions if present.
- **Verify:** full demo pass (`animation_test`, `face_component_test`, `cutscene_parliament`,
  `squad_battle_2d_demo`).

## 4. Parallelization / delegation

Phase 1 (body) and Phase 2 (face) touch **disjoint files** and can run in parallel — good
candidates for background delegation once Phase 0's findings are written down. Phase 3 depends on
Phase 2; Phase 4 depends on all.

## 5. Phase 0 findings (spike complete)

Spike: `scenes/demos/anim_tree_face_spike.tscn` + `src/demos/anim_tree_face_spike.gd`. Builds
face clips + blend graphs at runtime against the real `warrior_rig_2` face nodes and prints a
report. Reproduce: `godot --headless --path . scenes/demos/anim_tree_face_spike.tscn`
(`--gui` + LEFT/RIGHT scrubs the Q1 crossfade by eye).

**Q1 — Blend2 crossfade on the same nodes: SMOOTH.** `Blend2(brows_neutral, brows_sad)`
interpolates perfectly linearly: `blend_amount` 0→1 drives `BrowL.rotation` 0→0.35 in exact
proportion (0.25→0.0875, 0.5→0.175, ...), position likewise. Smooth expression transitions are
free.

**Q2 — Disjoint clips compose via `Add2`; use ABSOLUTE clips, not additive deltas.**
- `Add2(brows_sad, mouth_smile)` (each keys only its own part): BrowL got exactly sad, Mouth got
  exactly smile. **A track absent from one input contributes nothing — it is NOT zeroed.** This
  is the "key simplification": disjoint absolute poses merge cleanly.
- Additive *delta* clips (keyed as offsets from baseline) did **not** compose — the absolute base
  pose got clobbered (BrowL.pos collapsed to the raw delta). **Do not author additive deltas;
  author absolute target transforms.**
- **Validated production graph shape** (Q2c, all values exact):
  ```
  brows_blend = Blend2(brows_neutral, brows_sad)     # crossfade, brow tracks only
  mouth_blend = Blend2(mouth_neutral, mouth_smile)   # crossfade, mouth tracks only
  face_merge  = Add2(brows_blend, mouth_blend)       # merge disjoint per-part outputs
  output      = Add2(BodyStateMachine, face_merge)   # body has no face tracks -> safe base
  ```
  Independent control confirmed: brow at blend 0.5 while mouth at 0 → brow half-sad, mouth
  neutral. This is exactly "sad eyes + smile mouth independently."

**Q3 — RESET MUST carry every face-part track.** With a graph that doesn't key the face, face
parts held baseline while RESET had their tracks; with an EMPTY RESET they collapsed to
`scale ≈ (0,0)`, `position = (0,0)` (invisible). Same failure mode the bake tool already documents
for the body. **`_rebuild_reset` must include face-part position/rotation/scale once face clips
join the library.**

### Design rules that follow
- **Absolute clips**: each per-part expression clip keys its part at the *target* transform
  (position/rotation/scale), not a delta.
- **Disjointness is what makes `Add2` safe**: a clip keys ONLY its own part's nodes. The base of
  any `Add2` must not share tracks with a layer (or values double). Body has no face tracks →
  safe base; per-part `Blend2` outputs are mutually disjoint → safe to merge.
- **Per-part `Blend2`** gives correct crossfade midpoints (an `Add2` `add_amount` ramp does NOT —
  it scales absolute values from zero, wrong for position/scale).
- **RESET** carries the neutral transform of every face part.
