#define AUTOMATON_STATES 1
#define AUTOMATON_TRANSITIONS 2
#define AUTOMATON_ACCEPTING_STATES 3

/**
 * A deterministic finite automaton, or finite state machine.
 */

/datum/finite_automaton
	/// List of valid states.
	VAR_PRIVATE/list/states
	/// List of valid transitions. Format: list[state, list[symbol, state]]
	VAR_PRIVATE/list/transitions
	/// List of accepting states. Has to be a subset of states.
	VAR_PRIVATE/list/accepting_states
	/// The current state of this DFA. Contained in states.
	VAR_PRIVATE/current_state = null
	/// Whether this automaton is immutable. Blocks all varedits if it is.
	VAR_PRIVATE/immutable = FALSE

/**
 * Constructs a new finite automaton from the given structure.
 * - automaton_structure: A two dimensional list of states and a list of transitions
 * - first_state: The first state that should be assumed. Default will be the first state in the state list.
 * - force_immutable: Effectively hides the state machine from varedits. Set this to true if you use this state machine somewhere important.
 */
/datum/finite_automaton/New(automaton_structure, first_state = null, force_immutable = FALSE)
	if(!islist(automaton_structure))
		CRASH("Invalid automaton_structure")

	states = automaton_structure[AUTOMATON_STATES]
	transitions = automaton_structure[AUTOMATON_TRANSITIONS]
	accepting_states = automaton_structure[AUTOMATON_ACCEPTING_STATES]

	if(force_immutable)
		states = states.Copy()
		transitions = transitions.Copy()
		accepting_states = accepting_states.Copy()

	current_state = first_state || states[1]
	immutable = force_immutable

/// Returns whether the given symbol will result in a valid transition.
/datum/finite_automaton/can_transition(symbol)
	return (symbol in transitions[current_state])

/// Executes a transition if it exists. Returns the state on success.
/datum/finite_automaton/try_transition(symbol)
	var/next_state = transitions[current_state][symbol]
	if(!next_state)
		return null
	current_state = next_state
	return current_state

/// Returns whether the automaton is currently accepting.
/datum/finite_automaton/currently_accepting()
	return (current_state in accepting_states)

/// Forces the automaton to take on the current state. Only for the brave.
/datum/finite_automaton/force_state(state)
	if(!(state in states))
		CRASH("State [state] is not in accepting states")
	current_state = state

/datum/finite_automaton/can_vv_get(var_name)
	return immutable ? FALSE : ..()

/datum/finite_automaton/vv_edit_var(var_name, var_value)
	return immutable || var_name == NAMEOF(src, immutable) ? FALSE : ..()

#undef AUTOMATON_STATES
#undef AUTOMATON_TRANSITIONS
#undef AUTOMATON_ACCEPTING_STATES
