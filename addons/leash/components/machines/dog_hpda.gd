@tool
class_name DogHPDA
extends DogPDA
## Hierarchical pushdown automaton component.
##
## Combines the DogHFSM
## guard hierarchy with DogPDA stack behavior. Expects DogHPDAState
## instances on the stack.
##
## [codeblock]
## var idle_state     := PlayerIdleState.new()     # extends PlayerGroundedState
## var dialogue_state := PlayerDialogueState.new() # extends PlayerLockedState
##
## func _ready() -> void:
##     hpda.init(idle_state)
##
## func _process(delta: float) -> void:
##     hpda.update(delta)
##
## func _on_dialogue_started() -> void:
##     hpda.push(dialogue_state)
##
## func _on_dialogue_ended() -> void:
##     hpda.pop()
## [/codeblock]
