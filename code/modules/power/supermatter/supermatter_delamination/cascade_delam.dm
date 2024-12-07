/// The amount of time it takes from the last cascade emitter shot until the SM starts healing again.
#define HEAL_COOLDOWN (10 SECONDS)
/// The amount of cascade emitter hits it takes until the SM delaminates.
#define CASCADE_EMITTER_STRIKES 35 // 70 seconds
/// The amount of strikes it takes until the cascade announcement is made.
#define STRIKES_UNTIL_ANNOUNCEMENT 5 // 10 seconds after the first shot is made

/proc/delam_cascade_can_select(obj/machinery/power/supermatter_crystal/sm)
	if(!sm.is_main_engine)
		return FALSE
	var/total_moles = sm.absorbed_gasmix.total_moles()
	if(total_moles < MOLE_PENALTY_THRESHOLD * sm.absorption_ratio)
		return FALSE
	for (var/gas_path in list(/datum/gas/antinoblium, /datum/gas/hypernoblium))
		var/percent = sm.gas_percentage[gas_path]
		if(!percent || percent < 0.4)
			return FALSE
	return TRUE

/datum/sm_delam/cascade

/datum/sm_delam/cascade/delam_progress()
	if(!..())
		return FALSE

	sm.radio.talk_into(
		sm,
		"DANGER: HYPERSTRUCTURE OSCILLATION FREQUENCY OUT OF BOUNDS.",
		sm.damage >= sm.emergency_point ? sm.emergency_channel : sm.warning_channel
	)
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
	animate(sm.warp, time = 1, transform = matrix().Scale(0.5,0.5))
	animate(time = 9, transform = matrix())

/datum/sm_delam/cascade/on_deselect()
	message_admins("[sm] will no longer cascade. [ADMIN_VERBOSEJMP(sm)]")
	sm.investigate_log("will no longer cascade.", INVESTIGATE_ENGINE)

	sm.vis_contents -= sm.warp
	QDEL_NULL(sm.warp)

/datum/sm_delam/cascade/delaminate()
	message_admins("Supermatter [sm] at [ADMIN_VERBOSEJMP(sm)] triggered a cascade delam.")
	sm.investigate_log("triggered a cascade delam.", INVESTIGATE_ENGINE)

	effect_explosion(sm)
	effect_emergency_state()
	effect_cascade_demoralize()
	priority_announce("A Type-C resonance shift event has occurred in your sector. Scans indicate local oscillation flux affecting spatial and gravitational substructure. \
		Multiple resonance hotspots have formed. Please standby.", "Nanotrasen Astrophysics Division", ANNOUNCER_SPANOMALIES)
	sleep(3 SECONDS)
	effect_strand_shuttle()
	sleep(3 SECONDS)
	var/obj/cascade_portal/rift = effect_evac_rift_start()
	RegisterSignal(rift, COMSIG_QDELETING, PROC_REF(end_round_holder))
	SSsupermatter_cascade.can_fire = TRUE
	SSsupermatter_cascade.cascade_initiated = TRUE
	effect_crystal_mass(sm, rift)
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
		a subject within [station_name()], a resonance collapse may occur.",
		"Nanotrasen Astrophysics Division", 'sound/announcer/alarm/airraid.ogg')
	return TRUE

/// Signal calls cant sleep, we gotta do this.
/datum/sm_delam/cascade/proc/end_round_holder()
	SIGNAL_HANDLER
	INVOKE_ASYNC(src, PROC_REF(effect_evac_rift_end))

/proc/delam_cascade_emitter_can_select(obj/machinery/power/supermatter_crystal/sm)
	return FALSE

/datum/sm_delam/cascade/emitter
	var/strikes_remaining = CASCADE_EMITTER_STRIKES
	COOLDOWN_DECLARE(heal_cooldown)

/datum/sm_delam/cascade/emitter/modify_damage(damage_to_be_applied)
	// get it down to the emergency point, but not below, unless we are out of strikes then just allow all damage
	if(strikes_remaining > 0)
		damage_to_be_applied *= clamp((sm.emergency_point - (sm.damage + damage_to_be_applied)) / sm.emergency_point, 0, 1)

	// block healing unless its been HEAL_COOLDOWN seconds since the last shot
	if(!COOLDOWN_FINISHED(src, heal_cooldown))
		damage_to_be_applied = max(0, damage_to_be_applied)

	return damage_to_be_applied

/datum/sm_delam/cascade/emitter/on_bullet(obj/projectile/beam/emitter/hitscan/cascade/projectile)
	if(!istype(projectile))
		return FALSE

	strikes_remaining--
	sm.external_damage_immediate += 5
	COOLDOWN_START(src, heal_cooldown, HEAL_COOLDOWN)

	switch(strikes_remaining)
		if(CASCADE_EMITTER_STRIKES - STRIKES_UNTIL_ANNOUNCEMENT)
			announce_cascade()
		if(0)
			sm.external_damage_immediate = sm.explosion_point * 5 // no more saving this

	return TRUE
