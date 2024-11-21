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

/**
 * Constructs a new finite automaton from the given structure.
 * - automaton_structure: A two dimensional list of states and a list of transitions. If a transition symbol has no associated state then the symbol will be assumed as the state.
 * - first_state: The first state that should be assumed. Default will be the first state in the state list.
 * - force_immutable: Effectively hides the state machine from varedits. Set this to true if you use this state machine somewhere important.
 */
/datum/finite_automaton/New(automaton_structure, first_state = null)
	if(!islist(automaton_structure))
		CRASH("Invalid automaton_structure")

	states = automaton_structure[AUTOMATON_STATES]
	transitions = automaton_structure[AUTOMATON_TRANSITIONS]
	accepting_states = automaton_structure[AUTOMATON_ACCEPTING_STATES]

	current_state = first_state || states[1]

/// Returns whether the given symbol will result in a valid transition.
/datum/finite_automaton/can_transition(symbol)
	return (symbol in transitions[current_state])

/// Executes a transition if it exists. Returns the state on success.
/datum/finite_automaton/try_transition(symbol)
	if(!can_transition(symbol))
		return null
	var/next_state = transitions[current_state][symbol]
	if(!next_state)
		next_state = symbol
		if(!(next_state in states))
			stack_trace("Transition symbol \"[symbol]\" does not have a next state and isn't a state itself")
			return null
	current_state = next_state
	return next_state

/// Returns whether the automaton is currently accepting.
/datum/finite_automaton/currently_accepting()
	return (current_state in accepting_states)

/// Forces the automaton to take on the current state. Only for the brave.
/datum/finite_automaton/force_state(state)
	if(!(state in states))
		CRASH("State \"[state]\" is not a valid state")
	current_state = state

#undef AUTOMATON_STATES
#undef AUTOMATON_TRANSITIONS
#undef AUTOMATON_ACCEPTING_STATES
