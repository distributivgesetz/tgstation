/// The amount of time it takes from the last cascade emitter shot until the SM starts healing again.
#define HEAL_COOLDOWN (10 SECONDS)
/// The amount of cascade emitter hits it takes until the SM delaminates.
#define CASCADE_EMITTER_STRIKES 155 // 310 seconds
/// The amount of strikes it takes until the cascade announcement is made.
#define STRIKES_UNTIL_ANNOUNCEMENT 5 // 10 seconds after the first shot is made
/// The amount of strikes until we start to memorize saviours.
#define STRIKES_LEFT_UNTIL_MEMORIZE_SAVIORS 3

/proc/delam_cascade_can_select(obj/machinery/power/supermatter_crystal/sm)
	if(!sm.is_main_engine)
		return FALSE
	var/total_moles = sm.absorbed_gasmix.total_moles()
	if(total_moles < MOLE_PENALTY_THRESHOLD)
		return FALSE
	for (var/gas_path in list(/datum/gas/antinoblium, /datum/gas/hypernoblium))
		var/percent = sm.gas_percentage[gas_path]
		if(!percent || percent < 0.4)
			return FALSE
	return TRUE

/datum/sm_delam/cascade
	/// List of the crazy engineers who managed to turn a cascading engine around.
	var/list/datum/weakref/saviors = list()

/datum/sm_delam/cascade/delam_progress()
	// handle the engineers that saved the engine from cascading, if there were any
	if(sm.get_status() < SUPERMATTER_EMERGENCY)
		handle_post_emergency_point_award()

	if(!..())
		return FALSE

	sm.post_alert("DANGER: HYPERSTRUCTURE OSCILLATION FREQUENCY OUT OF BOUNDS.")
	var/list/messages = list(
		"Space seems to be shifting around you...",
		"You hear a high-pitched ringing sound.",
		"You feel tingling going down your back.",
		"Something feels very off.",
		"A drowning sense of dread washes over you.",
	)
	dispatch_announcement_to_players(span_danger(pick(messages)), should_play_sound = FALSE)

	return TRUE

/datum/sm_delam/cascade/on_select()
	message_admins("[sm] is heading towards a cascade. [ADMIN_VERBOSEJMP(sm)]")
	sm.investigate_log("is heading towards a cascade.", INVESTIGATE_ENGINE)

	sm.warp = new(sm)
	sm.vis_contents += sm.warp
	animate(sm.warp, transform = matrix().Scale(0.5,0.5))
	animate(time = 1 SECONDS, transform = matrix())

/datum/sm_delam/cascade/on_deselect()
	message_admins("[sm] will no longer cascade. [ADMIN_VERBOSEJMP(sm)]")
	sm.investigate_log("will no longer cascade.", INVESTIGATE_ENGINE)

	sm.vis_contents -= sm.warp
	QDEL_NULL(sm.warp)

/datum/sm_delam/cascade/on_leave_countdown()
	memorize_saviors()

/datum/sm_delam/cascade/proc/memorize_saviors()
	// save people who stuck around to save the engine
	for(var/mob/living/lucky_engi as anything in mobs_in_area_type(list(/area/station/engineering/supermatter)))
		if(isnull(lucky_engi.client))
			continue
		if(!ishuman(lucky_engi) && !issilicon(lucky_engi))
			continue
		saviors |= WEAKREF(lucky_engi)

/datum/sm_delam/cascade/proc/handle_post_emergency_point_award() // the wonders of inheritance
	award_saviors()

/datum/sm_delam/cascade/proc/award_saviors()
	for(var/datum/weakref/savior_ref as anything in saviors)
		var/mob/living/savior = savior_ref.resolve()
		if(!istype(savior)) // didn't live to tell the tale, sadly.
			continue
		savior.client?.give_award(/datum/award/achievement/jobs/theoretical_limits, savior)
		saviors -= savior_ref

/datum/sm_delam/cascade/delaminate()
	message_admins("Supermatter [sm] at [ADMIN_VERBOSEJMP(sm)] triggered a cascade delam.")
	sm.investigate_log("triggered a cascade delam.", INVESTIGATE_ENGINE)

	effect_explosion()
	effect_emergency_state()
	effect_cascade_demoralize()
	priority_announce("A Type-C resonance shift event has occurred in your sector. Scans indicate local oscillation flux affecting spatial and gravitational substructure. \
		Multiple resonance hotspots have formed. Please standby.", "Nanotrasen Astrophysics Division", ANNOUNCER_SPANOMALIES)
	sleep(4 SECONDS)
	effect_strand_shuttle()
	sleep(3 SECONDS)
	var/obj/cascade_portal/rift = effect_evac_rift_start()
	SSsupermatter_cascade.can_fire = TRUE
	SSsupermatter_cascade.cascade_initiated = TRUE
	effect_crystal_mass(rift)
	return ..()

/datum/sm_delam/cascade/examine()
	return list(span_bolddanger("The crystal is vibrating at immense speeds, warping space around it!"))

/datum/sm_delam/cascade/overlays()
	return list()

/datum/sm_delam/cascade/count_down_messages()
	var/list/messages = list()
	messages += "CRYSTAL DELAMINATION IMMINENT. The supermatter has reached critical integrity failure. Harmonic frequency limits exceeded. Causality destabilization field could not be engaged."
	messages += "Crystalline hyperstructure returning to safe operating parameters. Harmonic frequency restored within emergency bounds. Anti-resonance filter initiated."
	messages += "remain before resonance-induced stabilization."
	return messages

/datum/sm_delam/cascade/proc/announce_cascade()
	if(QDELETED(sm))
		return FALSE
	priority_announce("Attention: Long range anomaly scans indicate abnormal quantities of harmonic flux originating from \
		a subject within [station_name()], a resonance cascade event may occur.",
		"Nanotrasen Astrophysics Division", 'sound/announcer/alarm/airraid.ogg')
	return TRUE

/datum/sm_delam/cascade/emitter
	warn_time = SUPERMATTER_WARNING_DELAY / 2
	var/strikes_remaining = CASCADE_EMITTER_STRIKES
	COOLDOWN_DECLARE(heal_cooldown)

/datum/sm_delam/cascade/emitter/handle_post_emergency_point_award()
	return

/datum/sm_delam/cascade/emitter/on_deselect()
	. = ..()
	award_saviors()

/datum/sm_delam/cascade/emitter/modify_damage(damage_to_be_applied, list/individual_damages)
	// get it down to the emergency point, but not below, unless we are out of strikes then just allow all damage
	if(strikes_remaining > 0)
		var/half_emergency_point = sm.emergency_point + (sm.explosion_point - sm.emergency_point) / 2
		var/damage_mult = clamp((half_emergency_point - (sm.damage + damage_to_be_applied)) / half_emergency_point, 0, 1)
		damage_to_be_applied *= damage_mult
		for(var/damage_type in individual_damages)
			individual_damages[damage_type] *= damage_mult

	// block healing unless its been HEAL_COOLDOWN seconds since the last shot
	if(!COOLDOWN_FINISHED(src, heal_cooldown))
		damage_to_be_applied = max(0, damage_to_be_applied)
		for(var/damage_type in individual_damages)
			individual_damages[damage_type] = max(0, damage_type)

	return damage_to_be_applied

/datum/sm_delam/cascade/emitter/get_radio_alert_spans()
	return list(SPAN_COMMAND)

/datum/sm_delam/cascade/emitter/delam_progress()
	. = ..()
	if(strikes_remaining <= 0)
		sm.external_damage_immediate += 2.5 // quickly bleed integrity

/datum/sm_delam/cascade/emitter/on_bullet(obj/projectile/beam/emitter/hitscan/cascade/projectile)
	if(!istype(projectile))
		return FALSE

	if(strikes_remaining <= 0)
		return FALSE // nothing more to be done now

	strikes_remaining--
	sm.external_damage_immediate += 10
	COOLDOWN_START(src, heal_cooldown, HEAL_COOLDOWN)

	switch(strikes_remaining)
		if(CASCADE_EMITTER_STRIKES - STRIKES_UNTIL_ANNOUNCEMENT)
			announce_cascade()
		if(15)
			sm.post_alert("DANGER: OSCILLATION FREQUENCY APPROACHING FILTER LIMIT. FREQUENCY FILTER SHUTDOWN IMMINENT.") // "oh fuck" time
		if(1 to STRIKES_LEFT_UNTIL_MEMORIZE_SAVIORS)
			memorize_saviors()
		if(0)
			sm.post_alert("DANGER: FREQUENCY FILTER OVERLOAD. PLEASE CONTACT A REPAIR TECHNICIAN IMMEDIATELY.")  // no more saving this

	return TRUE
