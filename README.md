# AeroBeat Tool Template

This is the official template for creating **Tool** repositories within the current AeroBeat v1 architecture.

It should be read against the locked product direction from `aerobeat-docs`:

- **Primary release target:** PC community first
- **Official v1 gameplay features:** Boxing and Flow
- **Official v1 gameplay input:** camera only
- **Tool stance:** tools should stay workflow-oriented and gameplay-mode agnostic enough to support the current product slice without implying equal-status future gameplay/input/platform scope
- **Tool lane ownership:** shared tool-side DTOs, progress/result models, and workflow interfaces belong in `aerobeat-tool-core`; concrete authoring/import/export/validation tooling belongs in specific `aerobeat-tool-*` repos

## Naming rule: rename the manager after cloning

This template intentionally ships with `src/AeroToolManager.gd` as a **clone-time placeholder only**.

After creating a real repo from this template, a human or agent must rename that file/class/autoload entry to the repo's actual public manager name before treating the repo as real work.

Examples:

- `aerobeat-tool-api` → `AeroApiManager.gd`
- `aerobeat-tool-settings` → `AeroSettingsManager.gd`
- another import/export tool → a repo-specific manager name that matches its contract

`AeroToolManager` is **not** an acceptable shipped final runtime identity. The placeholder exists only because GitHub template clones do not yet perform token replacement for file/class names.

## 📋 Repository Details

- **Type:** Tool template
- **License:** **Mozilla Public License 2.0 (MPL 2.0)**
- **Dependency contract:**
  - `aerobeat-tool-core` — required shared tool/workflow contract
  - additional adjacent lane/core repos only when the specific tool actually consumes them (commonly `aerobeat-content-core` or `aerobeat-asset-core`)

## GodotEnv development flow

This repo uses the AeroBeat GodotEnv package convention.

- Canonical dev/test manifest: `.testbed/addons.jsonc`
- Installed dev/test addons: `.testbed/addons/`
- GodotEnv cache: `.testbed/.addons/`
- Hidden workbench project: `.testbed/project.godot`
- Repo-local unit tests: `.testbed/tests/`

The repo root remains the package/published boundary for downstream consumers. Day-to-day development, debugging, and validation happen from the hidden `.testbed/` workbench using the pinned OpenClaw toolchain: Godot `4.6.2 stable standard`.

### Restore dev/test dependencies

From the repo root:

```bash
cd .testbed
godotenv addons install
```

That restores this repo's current dev/test manifest into `.testbed/addons/`. Canonically, Tool templates should keep the baseline manifest narrow: `aerobeat-tool-core` plus test-only tooling.

### Open the workbench

From the repo root:

```bash
godot --editor --path .testbed
```

Use this `.testbed/` project as the canonical direct-development and bugfinding surface for tool-template work.

### Import smoke check

From the repo root:

```bash
godot --headless --path .testbed --import
```

### Run unit tests

From the repo root:

```bash
godot --headless --path .testbed --script addons/aerobeat-vendor-godot-unit-test/gut_cmdln.gd \
  -gdir=res://tests \
  -ginclude_subdirs \
  -gexit
```

### Validation notes

- `.testbed/addons.jsonc` is the committed dev/test dependency contract.
- The canonical template manifest for this repo is `aerobeat-tool-core` + `aerobeat-vendor-godot-unit-test`.
- `aerobeat-tool-core` is currently pinned to `main` intentionally because the repo does not yet have release tags; switch to a tag once tagged releases exist.
- If a concrete tool needs adjacent lane repos, add them intentionally rather than restoring a universal `aerobeat-core` baseline.
- Repo-local unit tests live under `.testbed/tests/` and currently validate repo metadata plus the template stub contract.
- The current package shape is consumed from the repo root (`subfolder: "/"`) for downstream installs.
