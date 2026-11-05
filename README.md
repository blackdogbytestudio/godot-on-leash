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
cluttering your scene tree. Declare the components as variables and
the facade registers them when it enters the tree:

```gdscript
var _jump: DogJump2D = DogJump2D.new()
var _move: DogMove2D = DogMove2D.new()
var _gravity: DogGravity2D = DogGravity2D.new()
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
3. Run `init` in the **Leash** bottom panel to create the project folders
   and the script templates (see [init](#init)).

Enabling the plugin creates nothing in your project; only `init` does.

## Generators

The plugin's bottom panel runs generator commands. Type `help` in the
panel to list them.

`help <command>` shows the options of one. A flag that a command does not
use is an error, never silently ignored.

### Where actors live

Every generator looks for an actor in one place, so its scene, script and
states are always where you expect. Two project settings under
`leash/generators/` decide it. They are written without the `res://`, which
is always the root:

| Setting           | Default             | Used for                                      |
| ----------------- | ------------------- | --------------------------------------------- |
| `implicit_folder` | `scenes/characters` | where an actor is when there is no `--folder` |
| `explicit_folder` | `scenes`            | where `--folder` starts from                  |

So `player` is `res://scenes/characters/player/player.tscn`. `--folder` is
the actor's own directory, written in full from `explicit_folder`:
`--folder characters/enemies/slime` is
`res://scenes/characters/enemies/slime/slime.tscn`. The scene is looked up
at that exact path, never searched for.

A folder is snake_case names separated by `/`, and an empty value means
`res://` itself. Anything else (`res://`, `..`, `//`, `,`) is an error, and
for a setting the message names it. The two settings don't depend on each
other, so changing one doesn't move the other.

### init

Sets up the project for leash.

```
init [--skip-templates]
```

It creates the folders listed in `addons/leash/config/scaffold.json`
(assets, scenes, scripts, components) below `res://` and copies the
script templates to `res://script_templates`, with a `.gdignore` so Godot
doesn't parse them. Only what is missing is created and nothing is ever
overwritten, so it is safe to run again. `--skip-templates` leaves the
templates out. It prints one line per item, `create <path>` or
`exist <path>`, and a warning when GUT is not installed
(`addons/gut/plugin.cfg`).

The folders it creates:

```
res://
├── assets/
│   ├── sprites/
│   │   ├── characters/
│   │   │   ├── player/
│   │   │   └── enemies/
│   │   ├── environment/
│   │   │   └── tilesets/
│   │   ├── ui/
│   │   ├── fx/
│   │   └── placeholders/
│   ├── sfx/
│   │   ├── characters/
│   │   ├── ui/
│   │   └── environment/
│   ├── music/
│   └── fonts/
├── scenes/
│   ├── characters/
│   │   ├── player/
│   │   └── enemies/
│   ├── levels/
│   │   └── tilemaps/
│   ├── objects/
│   ├── ui/
│   └── placeholders/
├── scripts/
│   ├── autoloads/
│   └── globals/
└── components/
```

The scaffold is fixed: it doesn't follow the folder settings above, so if
you change them, adjusting the folders is up to you. The generators read
templates from `res://script_templates` first and fall back to the addon's
own.

### actor

Creates an actor: its scene and its script.

```
actor <actor> [template] [--extends class] [--folder path] [-f]
```

`actor player` creates `res://scenes/characters/player/player.tscn` and
`player.gd`. Both are a copy of a scene template, never an instance of it:
the root is renamed after the actor and the script gets `class_name Player`.

A template is a PascalCase folder holding `<Template>.tscn` and
`<Template>.gd`. It is looked up in `res://scene_templates` first and then
in the addon's (`CharacterBody2D` is the default), so copying a folder to
`res://scene_templates` is how you make your own.

`--extends` makes the actor extend another class instead of the template's:
the script extends it and the root of the scene gets its native type
(`--extends Area2D`, `--extends CPUParticles2D`).

The command prints `created <path>` for each file. An actor whose scene and
script both exist is kept (`kept <path>`), and asking to change it with a
template or `--extends` is an error: `-f` recreates both from the template.
Only one of the two files existing is also an error. There is no `-u`:
nothing in a copy can be updated.

### state

Creates actor state scripts from the script templates.

```
state <actor> <fsm|pda|hfsm|hpda> <tree...> [--folder path] [--base class]
  [--initial state] [-f | -u]
```

The tree uses dots to express depth — `alive .grounded ..idle ..run dead`
makes `grounded` a child of `alive`, `idle` and `run` children of
`grounded`, and `dead` another root. `fsm`/`pda` are flat (no nesting) and
every state extends the actor base.

The actor's scene must exist first: `<actor>.tscn` in the actor's directory
(see [Where actors live](#where-actors-live)), with a saved `.gd` script on
its root. The machine is the direct child whose script is the machine of the
type (`fsm` → `DogFSM`, `pda` → `DogPDA`, `hfsm` → `DogHFSM`, `hpda` →
`DogHPDA`; the node name doesn't matter). When the root has none, the
command adds one to the scene, named after the class (`add node DogHPDA` in
the report); a machine of another type, or two of this one, is an error and
nothing is written. `-f` never touches the scene.

The states go in the `states/` folder of the actor's directory:

```
state enemy hpda --folder characters/enemies alive .grounded ..idle ..run dead
```

creates `res://scenes/characters/enemies/states/enemy_state.gd` (the actor
base, from `class.gd`) plus one `enemy_<state>_state.gd` per tree node
(from `state.gd`, extending its parent's class). Without `--folder` the
actor name is the folder, so `state player hpda run` writes to
`res://scenes/characters/player/states/`.

It also wires the machine into the actor's script, in Godot style guide
order: a `var <state>_state := <Actor><State>State.new()` per state, the
`@onready` reference to the machine node, `init(<initial>_state)` in
`_ready` and `update(delta)` as the first line of `_physics_process` (both
created when missing). The initial state is the deepest one (the first on a
tie) unless `--initial <state>` says otherwise; the command prints it.

Existing files are kept, so adding a state to an actor only writes the new
one — `state player hpda alive .grounded ..run` leaves `player_state.gd`
and `player_alive_state.gd` alone, and the script only gets what is missing.
`-u` also updates the script (e.g. the `init` line when the initial state
changed) and never touches state files. `-f` goes back to factory: it
deletes the actor's whole `states/` folder, recreates it from the tree and
rewrites the script below its header (the report lists every dropped file
and member; run `bind` again afterwards if you use it).

The states are typed to the actor's class, the actor in PascalCase
(`skinny_man` → `SkinnyMan`, `character_body_2d` → `CharacterBody2D`); for
states shared by several actors, run `state` on the parent actor.
`--base Class` makes the root states inherit that class (a class of the
project, or a native one, that inherits from RefCounted) instead of the
actor base, and skips generating the actor base:

```
state slime hpda --base EnemyAliveState jump
```

### bind

Fills the actor's script with an API that forwards to its components.

```
bind <actor> [component...] [--prefix p] [--suffix s | --no-fix]
  [--folder path] [-f | -u]
```

The script has to be attached to the root of `<actor>.tscn` (`actor` does
it). The components are the direct children of the root that have a
`class_name`; state machines are left to `state`. For each one, `bind`
writes an `@onready` reference, a forwarding func per public method and a
re-declared, connected signal per public signal. Members that start with
`_` are internal and never forwarded, and one that an earlier component
already provides is skipped with a warning.

Without a list it binds every such child, never adds nodes, and warns about
each child whose script has no `class_name`. With a list it binds only
those classes and adds to the scene the ones of your project that are not
there yet, as a node named after the class: `bind player jump WallClimb`.

It only adds what is missing. `-u` also rewrites generated funcs whose text
changed, and `-f` keeps the header and rewrites everything below it. It
prints `updated <path>` or `kept <path>` for the scene and the script.

### generate

Runs `actor`, `state` and `bind` on one actor, in that order.

```
generate <actor> [<fsm|pda|hfsm|hpda> <tree...>] [--bind a,b] [--template t]
  [--extends class] [--base class] [--folder path] [--initial state]
  [--prefix p] [--suffix s | --no-fix] [-f | -u]
```

```
generate player hpda alive .grounded ..idle ..run dead --bind platformer_facade
```

Each step gets the flags that apply to it and reads them as the command of
that name would, so the checks and the messages are the same:

- `actor` gets the template, `--extends` and `-f`, never `-u`: an existing
  actor is kept.
- `state` runs only with a type and a tree, and gets the tree, `--base`,
  `--initial`, `-f` and `-u`.
- `bind` always runs. It gets the components of `--bind` (comma separated),
  the prefix and suffix flags and `-u`, never `-f`, which would rewrite
  what `state` wrote.
- `--folder` goes to every step.

A flag that no step would use is an error (`--initial` without a tree,
`--prefix` without `--bind`). A failure in the middle undoes nothing: the
error lists what was already written.

### destroy

Deletes an actor, at three levels.

```
destroy <actor> [--folder path] [-r | -f]
```

- `destroy player` deletes `player.tscn`, `player.gd` and its `.gd.uid`,
  wherever the actor is.
- `-r` also deletes the `states/` folder, and the actor's directory when
  nothing else is left in it (what is left is reported as `kept`).
- `-f` deletes the directory with everything in it. It includes `-r`.

`-r` and `-f` delete folders, so the directory has to be named after the
actor (`--folder characters/enemies/slime` for `slime`). Anything else is
an error and nothing is deleted, which keeps a shared folder like
`enemies` safe. There is no confirmation and no trash: each path is printed
as it is deleted. Tests and the scenes that instance the actor are not
touched.

### Class names

Every class a command takes (the template, `--extends`, `--base`, the
`bind` components) is written in one of three formats:

- snake_case: `character_body_2d`
- PascalCase, taken as typed: `CharacterBody2D`, `WallClimb`
- hybrid: `CPU_particles_2d` is `CPUParticles2D`

Acronyms (`CPU`, `FSM`) only exist in PascalCase or hybrid; snake_case
turns them into `Cpu`. In `bind`, an all lower case name gets the prefix
and suffix around it (`jump` is `dog_jump_2d`, so `DogJump2D`), and a name
with any upper case letter is taken as typed. The two settings are
`leash/generators/prefix` (`dog`) and `leash/generators/suffix` (`2d`).
`--prefix` and `--suffix` replace one for a single run (`--prefix=` drops
that side) and `--no-fix` drops both: `--no-fix dog_jump_2d`.

## Running without the editor

The generators run from a terminal too, for scripts and CI:

```
godot --headless --import
godot --headless -s res://addons/leash/cli/leash_cmdln.gd -- bind player jump
```

`--import` runs once after a fresh checkout, to build the class cache the
commands need. Everything after `--` is the command line (`help` when
there is none). The output goes to stdout, and the exit code is 0 when the
command succeeded and 1 when it failed. Without the editor, nothing
reloads the scenes and scripts that are open there.

## License

MIT — see [LICENSE](./LICENSE).
