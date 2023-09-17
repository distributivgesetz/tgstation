/datum/status_effect/stacking/fire_handler
	duration = -1
	alert_type = null
	status_type = STATUS_EFFECT_REFRESH //Custom code
	on_remove_on_mob_delete = TRUE
	tick_interval = 2 SECONDS

	max_stacks = 20

	/// A particle effect, for things like embers - Should be set on update_particles()
	var/obj/effect/abstract/particle_holder/particle_effect

/datum/status_effect/stacking/fire_handler/on_creation(mob/living/new_owner, new_stacks, forced = FALSE)
	. = ..()

	if(isanimal(owner))
		clear_status_effect()
		return FALSE
	if(isbasicmob(owner))
		var/mob/living/basic/basic_owner = owner
		if(!(basic_owner.basic_mob_flags & FLAMMABLE_MOB))
			qdel(src)
			return FALSE

/datum/status_effect/stacking/fire_handler/on_apply()
	. = ..()
	update_particles()

/datum/status_effect/stacking/fire_handler/Destroy()
	if(particle_effect)
		QDEL_NULL(particle_effect)
	return ..()

/**
 * Updates the particles for the status effects
 * Should be handled by subtypes!
 */

/datum/status_effect/stacking/fire_handler/proc/update_particles()
	SHOULD_CALL_PARENT(FALSE)

/**
 * Setter and adjuster procs for firestacks
 *
 * Arguments:
 * - new_stacks
 *
 */

/datum/status_effect/stacking/fire_handler/proc/set_stacks(new_stacks)
	. = ..()
	cache_stacks()

/datum/status_effect/stacking/fire_handler/proc/adjust_stacks(new_stacks)
	. = ..()
	cache_stacks()

/**
 * Refresher for mob's fire_stacks
 */

/datum/status_effect/stacking/fire_handler/proc/cache_stacks()
	owner.fire_stacks = 0
	var/was_on_fire = owner.on_fire
	owner.on_fire = FALSE
	for(var/datum/status_effect/stacking/fire_handler/possible_fire in owner.status_effects)
		owner.fire_stacks += possible_fire.stacks * possible_fire.stack_modifier

		if(!istype(possible_fire, /datum/status_effect/stacking/fire_handler/fire_stacks))
			continue

		var/datum/status_effect/stacking/fire_handler/fire_stacks/our_fire = possible_fire
		if(our_fire.on_fire)
			owner.on_fire = TRUE

	if(was_on_fire && !owner.on_fire)
		owner.clear_alert(ALERT_FIRE)
	else if(!was_on_fire && owner.on_fire)
		owner.throw_alert(ALERT_FIRE, /atom/movable/screen/alert/fire)

/**
 * Used to update owner's effect overlay
 */

/datum/status_effect/stacking/fire_handler/proc/update_overlay()

/datum/status_effect/stacking/fire_handler/fire_stacks
	id = "fire_stacks" //fire_stacks and wet_stacks should have different IDs or else has_status_effect won't work
	remove_on_fullheal = TRUE

	enemy_types = list(/datum/status_effect/stacking/fire_handler/wet_stacks)
	stack_modifier = 1

	/// If we're on fire
	var/on_fire = FALSE
	/// Stores current fire overlay icon state, for optimisation purposes
	var/last_icon_state
	/// Reference to the mob light emitter itself
	var/obj/effect/dummy/lighting_obj/moblight
	/// Type of mob light emitter we use when on fire
	var/moblight_type = /obj/effect/dummy/lighting_obj/moblight/fire

/datum/status_effect/stacking/fire_handler/fire_stacks/on_creation(mob/living/new_owner, new_stacks, forced)
	. = ..()
	if(.)
		stack_decay = owner.fire_stack_decay_rate

/datum/status_effect/stacking/fire_handler/fire_stacks/tick(seconds_between_ticks)
	. = ..()
	if(!on_fire)
		return TRUE

	var/datum/gas_mixture/air = owner.loc.return_air()
	if(!air.gases[/datum/gas/oxygen] || air.gases[/datum/gas/oxygen][MOLES] < 1)
		clear_status_effect()
		return TRUE

	deal_damage(seconds_between_ticks)
	update_overlay()
	update_particles()

/datum/status_effect/stacking/fire_handler/fire_stacks/update_particles()
	if(on_fire)
		if(!particle_effect)
			particle_effect = new(owner, /particles/embers)
		if(stacks > MOB_BIG_FIRE_STACK_THRESHOLD)
			particle_effect.particles.spawning = 5
		else
			particle_effect.particles.spawning = 1
	else if(particle_effect)
		QDEL_NULL(particle_effect)

/**
 * Proc that handles damage dealing and all special effects
 *
 * Arguments:
 * - seconds_between_ticks
 *
 */

/datum/status_effect/stacking/fire_handler/fire_stacks/proc/deal_damage(seconds_per_tick)
	owner.on_fire_stack(seconds_per_tick, src)

	var/turf/location = get_turf(owner)
	location.hotspot_expose(700, 25 * seconds_per_tick, TRUE)

/**
 * Used to deal damage to humans and count their protection.
 *
 * Arguments:
 * - seconds_between_ticks
 * - no_protection: When set to TRUE, fire will ignore any possible fire protection
 *
 */

/datum/status_effect/stacking/fire_handler/fire_stacks/proc/harm_human(seconds_per_tick, no_protection = FALSE)
	var/mob/living/carbon/human/victim = owner
	var/thermal_protection = victim.get_thermal_protection()

	if(thermal_protection >= FIRE_IMMUNITY_MAX_TEMP_PROTECT && !no_protection)
		return

	if(thermal_protection >= FIRE_SUIT_MAX_TEMP_PROTECT && !no_protection)
		victim.adjust_bodytemperature(5.5 * seconds_per_tick)
		return

	victim.adjust_bodytemperature((BODYTEMP_HEATING_MAX + (stacks * 12)) * 0.5 * seconds_per_tick)
	victim.add_mood_event("on_fire", /datum/mood_event/on_fire)
	victim.add_mob_memory(/datum/memory/was_burning)

/**
 * Handles mob ignition, should be the only way to set on_fire to TRUE
 *
 * Arguments:
 * - silent: When set to TRUE, no message is displayed
 *
 */

/datum/status_effect/stacking/fire_handler/fire_stacks/proc/ignite(silent = FALSE)
	if(HAS_TRAIT(owner, TRAIT_NOFIRE))
		return FALSE

	on_fire = TRUE
	if(!silent)
		owner.visible_message(span_warning("[owner] catches fire!"), span_userdanger("You're set on fire!"))

	if(moblight_type)
		if(moblight)
			qdel(moblight)
		moblight = new moblight_type(owner)

	SEND_SIGNAL(owner, COMSIG_LIVING_IGNITED, owner)
	cache_stacks()
	update_overlay()
	update_particles()
	return TRUE

/**
 * Handles mob extinguishing, should be the only way to set on_fire to FALSE
 */

/datum/status_effect/stacking/fire_handler/fire_stacks/proc/extinguish()
	QDEL_NULL(moblight)
	on_fire = FALSE
	owner.clear_mood_event("on_fire")
	SEND_SIGNAL(owner, COMSIG_LIVING_EXTINGUISHED, owner)
	cache_stacks()
	update_overlay()
	update_particles()
	for(var/obj/item/equipped in owner.get_equipped_items())
		equipped.extinguish()

/datum/status_effect/stacking/fire_handler/fire_stacks/on_remove()
	if(on_fire)
		extinguish()
	set_stacks(0)
	update_overlay()
	update_particles()
	return ..()

/datum/status_effect/stacking/fire_handler/fire_stacks/update_overlay()
	last_icon_state = owner.update_fire_overlay(stacks, on_fire, last_icon_state)

/datum/status_effect/stacking/fire_handler/fire_stacks/on_apply()
	. = ..()
	update_overlay()

/obj/effect/dummy/lighting_obj/moblight/fire
	name = "fire"
	light_color = LIGHT_COLOR_FIRE
	light_range = LIGHT_RANGE_FIRE

/datum/status_effect/stacking/fire_handler/wet_stacks
	id = "wet_stacks"

	enemy_types = list(/datum/status_effect/stacking/fire_handler/fire_stacks)
	stack_modifier = -1

/datum/status_effect/stacking/fire_handler/wet_stacks/tick(seconds_between_ticks)
	adjust_stacks(-0.5 * seconds_between_ticks)
	if(stacks <= 0)
		clear_status_effect()

/datum/status_effect/stacking/fire_handler/wet_stacks/update_particles()
	if(particle_effect)
		return
	particle_effect = new(owner, /particles/droplets)
