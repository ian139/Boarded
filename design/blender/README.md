# Boarded climbing-wall and climber campaign asset

Original, stylized promotional artwork inferred from the supplied climbing-wall reference. This packet affects **web only**; it changes no native surfaces, identity tokens, route data, or shared semantics. The wall is decorative artwork, not a construction plan or authored climbing route.

## Canonical files

- `boarded-wall.blend`: editable wall, articulated clay climber, studio camera and lighting, and baked ascent action.
- `generate_boarded_wall.py`: deterministic wall modeling, character integration, GLB export and transparent poster rendering.
- `climber_ascent.py`: character construction, real hold targets, offline two-link limb solving, continuous bend-plane transport, skin weights and animation baking.
- `render_climber_review.py`: headless contact sheets and close-up evidence for the fastest arm transition.
- `asset-stats.json`: measured runtime geometry and payload statistics.
- `climber-contact-report.json`: sampled reach, joint continuity, planted contact and geometric clearance checks.
- `../../public/walls/generated/boarded-wall.glb`: optimized PBR geometry and the single `ClimberAscent` animation, with no textures, lights or cameras.
- `../../public/walls/generated/boarded-wall-poster.webp`: transparent, exact frame-zero fallback from the same model and hero viewpoint.

## Runtime contract

The nominal wall measures 2.4384 m wide × 3.6576 m high (8 × 12 ft), with a 14° overhang, short vertical kickboard, 31 resin holds and three shallow graphite volumes. The roughly 1.5 m climber uses 16 bones and rigidly weighted, rounded overlapping parts. The wall has twelve material primitives and the character has seven: **19 draws** in total, before any runtime shadow pass.

The GLB uses meters, **+Y up, +Z front**, and the original wall-centered origin. `BoardedWall` remains unanimated. `ClimberRig` and its skinned mesh are descendants of that root. The original wall-only pivot is preserved; the larger animated bounds never recenter the wall.

`ClimberAscent` spans **exactly 0–12 seconds**, sampled at frames 0–360 at 30 fps. Six principal stance levels contain eighteen sequential hand/foot transfers. Each moving extremity clears the face along an eased arc; the other three remain planted on specific existing hold coordinates. Pelvis shifts, elbow and knee bends, head tracking, and a small final lift make the ascent readable. At the summit, both hands remain on the upper holds and both feet remain planted on high holds as the head peeks over the cap. No physics simulation, procedural browser IK, or runtime rig solver is required.

Three.js should scrub the clip with `mixer.setTime(12 * ascentProgress)` and keep its final pose for the summit beat. Rotation belongs to a shared parent around **both wall and climber**, independent of scroll: a slow automatic turn, with no drag or manual rotation control. The runtime then rapidly scales/translates that same parent for the summit exit. The obsolete `WallTurn` action is removed. Reduced motion uses the static frame-zero poster; pause animation work while hidden or offscreen.

The poster camera in glTF space is `(5.9, 5.2, 10)`, looking at `(0, 0.07, 0)`, with a 4.70 m orthographic vertical span and no extra root yaw. Preserve this framing on first load to avoid a poster/model jump. Expanded conservative animated bounds are included in the statistics and contact report; skinned-mesh culling must account for the full ascent.

## Rebuild and review

Use Blender 5.2 or later. From the repository root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python design/blender/generate_boarded_wall.py
/Applications/Blender.app/Contents/MacOS/Blender --background design/blender/boarded-wall.blend --python-exit-code 1 --python design/blender/render_climber_review.py
```

All generation runs inside Blender without external textures, add-ons, Python packages, downloaded assets or AI raster generation. Keep the three Python files together in `design/blender/` when extracting an asset bundle. Inspection PNGs and contact sheets are written to `work/asset-previews/` and are not browser dependencies.

The contact report checks every baked frame, comparing evaluated bone-space contact markers against their planted hold anchors rather than comparing target coordinates alone. It also checks fixed limb lengths, adjacent-frame joint movement, limb capsule clearance from the wall, and conservative capsule/volume intersections. The geometric capsule checks supplement independent rendered-image and browser playback review; they are not a structural or climbing-safety certification.
