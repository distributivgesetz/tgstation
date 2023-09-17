
/// Status effects that can stack.
/datum/status_effect/stacking
	id = "stacking_base"
	duration = -1 // Only removed under specific conditions.
	tick_interval = 1 SECONDS // Deciseconds between decays, once decay starts
	alert_type = null
	status_type = STATUS_EFFECT_REFRESH
	/// How many stacks are currently accumulated.
	/// Also, the default stacks number given on application.
	var/stacks = 0
	// Deciseconds until ticks start occuring, which removes stacks
	/// (first stack will be removed at this time plus tick_interval)
	var/delay_before_decay
	/// How many stacks are lost per tick (decay trigger)
	var/stack_decay = 1
	/// The threshold for having special effects occur when a certain stack number is reached
	var/stack_threshold
	/// The maximum number of stacks that can be applied
	var/max_stacks
	/// If TRUE, the status effect is consumed / removed when stack_threshold is met
	var/consumed_on_threshold = TRUE
	/// Set to true once the stack_threshold is crossed, and false once it falls back below
	var/threshold_crossed = FALSE

	/// What status effect types do we remove uppon being applied. These are just deleted without any deduction from our or their stacks when forced.
	var/list/enemy_types
	/// What status effect types do we merge into if they exist. Ignored when forced.
	var/list/merge_types
	/// What status effect types do we override if they exist. These are simply deleted when forced.
	var/list/override_types
	/// For how many stacks does one our stack count
	var/stack_modifier = 1

	/// Icon file for overlays applied when the status effect is applied
	var/overlay_file
	/// Icon file for underlays applied when the status effect is applied
	var/underlay_file
	/// Icon state for overlays applied when the status effect is applied
	/// States in the file must be given a name, followed by a number which corresponds to a number of stacks.
	/// Put the state name without the number in these state vars
	var/overlay_state
	/// Icon state for underlays applied when the status effect is applied
	/// The number is concatonated onto the string based on the number of stacks to get the correct state name.
	var/underlay_state
	/// A reference to our overlay appearance
	var/mutable_appearance/status_overlay
	/// A referenceto our underlay appearance
	var/mutable_appearance/status_underlay

/datum/status_effect/stacking/on_creation(mob/living/new_owner, stacks_to_apply, forced = FALSE)
	. = ..()

	if(QDELETED())
		return

	for(var/enemy_type in enemy_types)
		var/datum/status_effect/stacking/enemy_effect = owner.has_status_effect(enemy_type)
		if(enemy_effect)
			if(forced)
				qdel(enemy_effect)
				continue

			var/cur_stacks = stacks
			adjust_stacks(-abs(enemy_effect.stacks * enemy_effect.stack_modifier / stack_modifier))
			enemy_effect.adjust_stacks(-abs(cur_stacks * stack_modifier / enemy_effect.stack_modifier))
			if(enemy_effect.stacks <= 0)
				qdel(enemy_effect)

			if(stacks <= 0)
				qdel(src)
				return

	if(!forced)
		var/list/merge_effects = list()
		for(var/merge_type in merge_types)
			var/datum/status_effect/stacking/merge_effect = owner.has_status_effect(merge_type)
			if(merge_effect)
				merge_effects += merge_effects

		if(LAZYLEN(merge_effects))
			for(var/datum/status_effect/stacking/merge_effect in merge_effects)
				merge_effect.adjust_stacks(stacks * stack_modifier / merge_effect.stack_modifier / LAZYLEN(merge_effects))
			qdel(src)
			return

	for(var/override_type in override_types)
		var/datum/status_effect/stacking/override_effect = owner.has_status_effect(override_type)
		if(override_effect)
			if(forced)
				qdel(override_effect)
				continue

			adjust_stacks(override_effect.stacks)
			qdel(override_effect)

	set_stacks(stacks_to_apply)

/datum/status_effect/stacking/refresh(mob/living/new_owner, new_stacks, forced = FALSE)
	if(forced)
		set_stacks(new_stacks)
	else
		adjust_stacks(new_stacks)

/datum/status_effect/stacking/tick(seconds_between_ticks)
	if(!can_have_status())
		qdel(src)
	else
		adjust_stacks(-stack_decay)
		on_stack_decay()

/datum/status_effect/stacking/on_apply()
	if(!can_have_status())
		return FALSE
	status_overlay = mutable_appearance(overlay_file, "[overlay_state][stacks]")
	status_underlay = mutable_appearance(underlay_file, "[underlay_state][stacks]")
	var/icon/I = icon(owner.icon, owner.icon_state, owner.dir)
	var/icon_height = I.Height()
	status_overlay.pixel_x = -owner.pixel_x
	status_overlay.pixel_y = FLOOR(icon_height * 0.25, 1)
	status_overlay.transform = matrix() * (icon_height / world.icon_size) //scale the status's overlay size based on the target's icon size
	status_underlay.pixel_x = -owner.pixel_x
	status_underlay.transform = matrix() * (icon_height / world.icon_size) * 3
	status_underlay.alpha = 40
	owner.add_overlay(status_overlay)
	owner.underlays += status_underlay
	return ..()

/datum/status_effect/stacking/Destroy()
	if(owner)
		owner.cut_overlay(status_overlay)
		owner.underlays -= status_underlay
	QDEL_NULL(status_overlay)
	return ..()

/// Effects that occur if the status effect is removed due to the stack_threshold being crossed
/datum/status_effect/stacking/proc/on_stacks_consumed()
	return

/// Effects that occur if the status is removed due to being under 1 remaining stack
/datum/status_effect/stacking/proc/on_fadeout()
	return

/// Runs every time tick(), causes stacks to decay over time
/datum/status_effect/stacking/proc/on_stack_decay()
	return

/// Called when the stack_threshold is crossed (stacks go over the threshold)
/datum/status_effect/stacking/proc/on_threshold_cross()
	if(consumed_on_threshold)
		on_stacks_consumed()
		qdel(src)

/// Called when the stack_threshold is uncrossed / dropped (stacks go under the threshold after being over it)
/datum/status_effect/stacking/proc/on_threshold_drop()
	return

/// Whether the owner can have the status effect.
/// Return FALSE if the owner is not in a valid state (self-deletes the effect), or TRUE otherwise
/datum/status_effect/stacking/proc/can_have_status()
	return TRUE

/// Whether the owner can currently gain stacks or not
/// Return FALSE if the owner is not in a valid state, or TRUE otherwise
/datum/status_effect/stacking/proc/can_gain_stacks()
	return TRUE

/// Add (or remove) [stacks_added] stacks to our current stack count.
/datum/status_effect/stacking/proc/adjust_stacks(stacks_added)
	if(stacks_added > 0 && !can_gain_stacks())
		return FALSE
	owner.cut_overlay(status_overlay)
	owner.underlays -= status_underlay
	set_stacks(stacks + stacks_added)
	if(stacks > 0)
		if(stacks >= stack_threshold && !threshold_crossed) //threshold_crossed check prevents threshold effect from occuring if changing from above threshold to still above threshold
			threshold_crossed = TRUE
			on_threshold_cross()
			if(consumed_on_threshold)
				return
		else if(stacks < stack_threshold && threshold_crossed)
			threshold_crossed = FALSE //resets threshold effect if we fall below threshold so threshold effect can trigger again
			on_threshold_drop()
		if(stacks_added > 0)
			tick_interval += delay_before_decay //refreshes time until decay
		status_overlay.icon_state = "[overlay_state][stacks]"
		status_underlay.icon_state = "[underlay_state][stacks]"
		owner.add_overlay(status_overlay)
		owner.underlays += status_underlay
	else
		on_fadeout()
		qdel(src) //deletes status if stacks fall under one

/datum/status_effect/stacking/proc/set_stacks(stack_amount)
	stacks = clamp(stack_amount, 0, max_stacks)
