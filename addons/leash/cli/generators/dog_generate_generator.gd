@tool
class_name DogGenerateGenerator
extends RefCounted
## Runs the actor, state and bind generators, in that order, on one actor: the
## actor is created (or kept), its states are generated when there is a `state`
## step, and everything in its scene is bound last.
##
## build checks everything that does not need the actor's scene on disk, so that
## nothing is written when one of those checks fails: the whole actor build, the
## state checks that need no scene (see DogStateGenerator.check) and the listed
## components (see DogBindGenerator.listed_error). What needs the scene runs in
## generate, after the actor is written. A step that fails there stops the run
## without undoing the steps before it: `written` lists what is already on disk.

const ACTOR_STEP := "actor"
const STATE_STEP := "state"
const BIND_STEP := "bind"


## build + the three steps. Stops at the first step that fails.
static func generate(options: Options) -> Result:
	var result := build(options)
	if not result.error.is_empty():
		return result

	result.actor = DogActorGenerator.generate(options.actor)
	result.written.append_array(result.actor.written)
	if _failed(result, ACTOR_STEP, result.actor.error):
		return result

	if options.state != null:
		result.state = DogStateGenerator.generate(options.state)
		if _failed(result, STATE_STEP, result.state.error):
			result.written.append_array(result.state.written)
			return result
		result.written.append_array(DogStateGenerator.written_paths(result.state))

	result.bind = DogBindGenerator.generate(options.bind)
	if _failed(result, BIND_STEP, result.bind.error):
		return result
	result.written.append_array(_bind_written(result.bind))
	return result


## The checks that need no actor scene. Writes nothing. Returns a Result with
## `error` and `step` set when one fails, and the actor build in `actor`.
static func build(options: Options) -> Result:
	var result := Result.new()
	result.actor = DogActorGenerator.build(options.actor)
	if _failed(result, ACTOR_STEP, result.actor.error):
		return result
	if options.state != null:
		if _failed(result, STATE_STEP, DogStateGenerator.check(options.state)):
			return result
	_failed(result, BIND_STEP, DogBindGenerator.listed_error(options.bind.components))
	return result


## Sets the error of `step` on `result` when `error` is not empty. Returns whether
## it did.
static func _failed(result: Result, step: String, error: String) -> bool:
	if error.is_empty():
		return false
	result.error = error
	result.step = step
	return true


## The scene and the host script, when bind changed them.
static func _bind_written(bind: DogBindGenerator.Result) -> Array[String]:
	var paths: Array[String] = []
	if bind.scene_source != bind.scene_original:
		paths.append(bind.scene)
	if bind.source != bind.original:
		paths.append(bind.path)
	return paths


## The options of each step. `state` is null when there is no state step.
class Options:
	var actor := DogActorGenerator.Options.new()
	var state: DogStateGenerator.Options = null
	var bind := DogBindGenerator.Options.new()


class Result:
	## The error of the step that failed, and that step (ACTOR_STEP, ...).
	var error := ""
	var step := ""
	## The result of each step that ran, null otherwise.
	var actor: DogActorGenerator.Result = null
	var state: DogStateGenerator.Result = null
	var bind: DogBindGenerator.Result = null
	## Every path written so far, in order.
	var written: Array[String] = []
