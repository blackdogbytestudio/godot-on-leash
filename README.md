# Godot On Leash

> Convention over configuration, Rails-style, for Godot.

An opinionated, component-based addon for Godot with state machines, built
for fast prototyping that scales into full games. Inspired by Ruby on
Rails: follow the conventions and the generators write the boilerplate for
you.

Godot On Leash is the leash. The `Dog*` classes (components, facades, state
machines) are the dogs. That's why the code says `DogComponent` and not
`LeashComponent`: you hold the leash, and everything you attach to it is a
dog.

> **Status:** Still in early experimentation and likely to have bugs. Good
> for testing ideas and prototypes — not yet validated for a full game.

## Philosophy

Godot gives you total freedom — which is great, until your `Player.gd`
turns into a 500-line file mixing movement, state, input, and everything
else. Godot On Leash takes its inspiration straight from Rails and its idea
of **convention over configuration**: follow the structure and it handles
the plumbing (component wiring, state transitions, project scaffolding), so
you focus on the game.

The convention is what pays off. Every actor looks the same, every state
lives in a predictable place with a predictable name, and the boilerplate
isn't something you type: the [generators](#generators) create it for you.
Like `rails generate`, one command gives you the files in the right place,
already wired the way the framework expects.

It's "dumb by design." Godot On Leash doesn't guard against every possible
misuse — if you attach the wrong component to the wrong host, it fails
loudly and predictably instead of silently working around it.

## Core Concepts

### Components

A `DogComponent` is a `Node` that encapsulates one isolated behavior
(movement, jumping, gravity...) and validates its own host type
automatically — attach it to the wrong node and Godot flags a
configuration warning right in the Scene dock.

### Facades

A `DogFacade` orchestrates several components and exposes them as a
single, flattened `@export` surface — so your Inspector shows one clean
set of grouped properties instead of five separate component nodes
cluttering your scene tree. Facades register their components in
`dog_leash()`:

```gdscript
func dog_leash(...components: Array) -> void:
    super.dog_leash(_jump, _move, _gravity)
```

`DogPlatformerFacade2D` ships out of the box, wrapping `DogJump2D`
(multi-jump, coyote time, jump buffering, jump cut, wall jump/slide),
`DogMove2D`, and `DogGravity2D` behind grouped `@export_group`
properties (Jump / Move / Gravity).

### State Machines

States are pure `RefCounted` objects — they never enter the scene tree.
The host is passed explicitly into `enter(host)`, `exit(host)`, and
`update(host, delta)`.

- **`DogFSM`** — flat state machine. States return the next `DogState`
  from `update()` to transition; `force()` transitions from the outside;
  `lock()`/`unlock()` blocks transitions when needed (e.g. mid-animation).
- **`DogHFSM`** — hierarchical FSM. State hierarchy is just GDScript
  inheritance — call `super()` first in `update()` so parent states can
  intercept transitions before child logic runs.
- **`DogPDA`** — pushdown automaton. `push()` suspends the current state
  (`pause()`) and activates a new one; `pop()` exits the top and resumes
  the one below. Built for interrupt states like pause menus or hit-stun.
- **`DogHPDA`** — combines the guard hierarchy of HFSM with the
  pause/resume stack of PDA.

```gdscript
func _ready() -> void:
    fsm.init(idle_state)

func _physics_process(delta: float) -> void:
    fsm.update(delta)

func _on_hitbox_area_entered(_area: Area2D) -> void:
    fsm.force(hurt_state)
```

## Installation

1. Copy `addons/leash/` into your project's `addons/` folder.
2. Enable **Godot On Leash** under **Project → Project Settings → Plugins**.
3. Enabling the plugin automatically:
   - Scaffolds your project's folder structure from
     `config/scaffold.json` (assets, scenes, scripts, components —
     editable after first install, idempotent on re-enable)
   - Installs the script templates into `res://script_templates`

> **Note:** Disabling the plugin does not remove anything it installed —
> the scaffolded folders, `config/scaffold.json`, and
> `res://script_templates` are left untouched. Removing them is a manual
> step.

## Generators

The plugin's bottom panel runs generator commands. Type `help` in the
panel to list them.

### state

Creates actor state scripts from the script templates.

```
state <fsm|pda|hfsm|hpda> <actor> <tree...> [--folder path] [--extends State] [--initial state] [-f | -u]
```

The tree uses dots to express depth — `alive .grounded ..idle ..run dead`
makes `grounded` a child of `alive`, `idle` and `run` children of
`grounded`, and `dead` another root. `fsm`/`pda` are flat (no nesting) and
every state extends the actor base.

The actor's scene must exist first: `<folder or actor>/<actor>.tscn` under
`res://scenes/characters/`, with a saved `.gd` script on its root and one
direct child whose script is the machine of the type (`fsm` → `DogFSM`,
`pda` → `DogPDA`, `hfsm` → `DogHFSM`, `hpda` → `DogHPDA`; the node name
doesn't matter). Otherwise nothing is written.

Files are written under `res://scenes/characters/`:

```
state hpda enemy --folder enemies alive .grounded ..idle ..run dead
```

creates `res://scenes/characters/enemies/states/enemy_state.gd` (the actor
base, from `class.gd`) plus one `enemy_<state>_state.gd` per tree node
(from `state.gd`, extending its parent's class). Without `--folder` the
actor name is the folder, so `state hpda player run` writes to
`res://scenes/characters/player/states/`.

It also wires the machine into the actor's script, in Godot style guide
order: a `var <state>_state := <Actor><State>State.new()` per state, the
`@onready` reference to the machine node, `init(<initial>_state)` in
`_ready` and `update(delta)` as the first line of `_physics_process` (both
created when missing). The initial state is the deepest one (the first on a
tie) unless `--initial <state>` says otherwise; the command prints it.

Existing files are kept, so adding a state to an actor only writes the new
one — `state hpda player alive .grounded ..run` leaves `player_state.gd`
and `player_alive_state.gd` alone, and the script only gets what is missing.
`-u` also updates the script (e.g. the `init` line when the initial state
changed) and never touches state files. `-f` goes back to factory: it
deletes the actor's whole `states/` folder, recreates it from the tree and
rewrites the script below its header (the report lists every dropped file
and member; run `api` again afterwards if you use it).

The states are typed to the actor's class, the actor in PascalCase
(`skinny_man` → `SkinnyMan`, `character_body_2d` → `CharacterBody2D`); for
states shared by several actors, run `state` on the parent actor.
`--extends State` makes the root states inherit that state
instead of the actor base and skips generating the actor base, e.g.
`state hpda slime --extends enemy_alive_state --folder enemies/slime jump`.

## Project Structure (addon)

```
addons/leash/
  components/
    dog_component.gd          # base for all components
    facades/
      dog_facade.gd            # base for all facades
      2d/character/
        dog_character_facade_2d.gd
        dog_platformer_facade_2d.gd
    machines/
      dog_machine.gd  dog_fsm.gd  dog_hfsm.gd  dog_pda.gd  dog_hpda.gd
    2d/character/
      dog_move_2d.gd  dog_jump_2d.gd  dog_gravity_2d.gd  dog_character_2d.gd
  states/
    dog_state.gd  dog_fsm_state.gd  dog_hfsm_state.gd
    dog_pda_state.gd  dog_h_pda_state.gd
  cli/                         # editor CLI behind the bottom panel
    dog_cli.gd  dog_command.gd  dog_panel.gd
    commands/                  # one file per command (state, api, help, ...)
    generators/                # build + write the files a command produces
    helpers/                   # pure helpers: script merge, render, names, state tree
    third_party/               # vendored code (optparse from GUT)
  setup/                       # scaffolding + template installers
  scaffold.json                # default project scaffold
```

## License

MIT — see [LICENSE](./LICENSE).
