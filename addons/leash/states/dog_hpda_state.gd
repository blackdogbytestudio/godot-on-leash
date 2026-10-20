@abstract
class_name DogHPDAState
extends DogPDAState
## Base class for states that live on a DogHPDA stack.
##
## A state that adds a guard hierarchy to
## DogPDAState, allowing parent states to intercept transitions before
## the child state executes its own behavior.
##
## [codeblock]
## enter  → state becomes active
## pause  → state is suspended
## resume → state becomes active again
## exit   → state is removed from the stack
## [/codeblock]
##
## [br]
## [b]Guard convention:[/b]
## Call [code]super()[/code] as the first line of [method update].
## If it returns a state, the guard has intercepted the update and
## that state should be returned.
##
## [br]
## [b]Example hierarchy:[/b]
## [codeblock]
## AliveState
##     └─ GroundedState
##         └─ IdleState
##
## dead     → DeadState
## airborne → AirborneState
## movement → IdleState
## [/codeblock]
