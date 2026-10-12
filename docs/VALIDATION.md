# Validation record

Validated on **2026-10-11**, using **Godot 4.7.1 stable official (a13da4feb)** on Windows. Graphical capture used the Compatibility renderer, OpenGL 3.3, and an NVIDIA GeForce RTX 3070 Ti.

## Executed checks

- **Headless editor import:** `--headless --editor --quit --log-file final-import.log` completed with exit code 0. Global scripts, scene references, ten recipe resources and original SVG imported. The final run reported no script/resource errors.
- **Main scene launch:** ran the configured project headlessly for 120 frames. Later integration and graphical capture runs instantiated the same main scene successfully.
- **Automated suite:** `tools/test.ps1 -UserData` completed with **90 checks, zero failures, exit code 0**. Its final log contains no script errors or leaked-instance warnings.
- **Graphical execution:** `tests/capture.gd` rendered seven captures with the real OpenGL driver, completed with exit code 0, and reported no errors. Inspected the introduction, starting pod, cargo interior, frigate at maximum survey zoom, completed station, navigation chart and fabrication interface.

The suite checks unit conversion/heading, guaranteed and duplicate loot, inventory capacity, atomic resource consumption, equipment delivery, distinct fragment counting, duplicate/unknown fragment rejection, blueprint gates, connected placement, overlap, diagonal connections, power deficit, isolated components, passive pod bus connections, room life support and full completion using authored resource yields. It validates JSON restoration of resources, tools, scans, partial scans, structures, graph, reserves, fog, logs, waypoints and objectives, plus malformed-save rejection and death/consumable behavior. Separate actual `user://` test files are written, loaded and removed.

Live scene tests use injected keyboard input to verify acceleration, momentum and braking. They test actual collision at an intact hull and southern breach, scanner ray occlusion, constructed module walls and docking openings, surface detection, suit consumption, pod refills and intermittent electrical damage. They also exercise the scanner handler, zoom bounds, physical placement checks, pod/fabricator interaction, recorder coordinate discovery and every menu constructor.

## Review scope and limits

The end-to-end economy/research/station milestone was exercised programmatically against authored content; it was not a complete human mouse-and-keyboard playthrough. Graphical review checks readability/composition and real shader/render execution, including normal and maximum zoom. Audio synthesis and playback ran in the graphical scene, but subjective audio quality was not independently evaluated. A formal frame-time benchmark on multiple hardware configurations, long-session soak testing, exported standalone builds and campaign balance were not performed.

Initial restricted runs could not write Godot's normal editor/user/shader-cache directories and emitted an operating-system certificate-store warning. Final editor, user-data and graphical checks ran with the required directory access and without those environment errors. Integration tests now isolate their save paths and skip audio in headless mode; they do not alter the expedition save.

## Intentional simplifications

- Square modules and four always-open docking airlocks; abstract life-support field instead of gas/pressure simulation.
- Immediate network availability with a 1.8-second visual assembly effect.
- Whole-module solar/recycler/array footprints; cosmetic quarter-turn rotation with symmetric docking.
- Equipment tracked as suit capabilities, consumables as inventory stacks; deterministic salvage.
- Cutaway interiors and additive flashlight cone without light-occlusion shadows.
- Minimal procedural audio, fixed keyboard controls, no gamepad or key rebinding.
- One save slot and a local handcrafted battlefield. Post-completion distant signals are narrative contacts.

These systems are functional within the slice. The README and architecture document identify their extension points.
