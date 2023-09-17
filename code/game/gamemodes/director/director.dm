/datum/game_mode/director
	var/list/departmental_targets = list()

	var/list/director_targets = list()

	var/static/list/director_target_keys = list(
		DIRECTOR_TARGET_COMMAND,
		DIRECTOR_TARGET_CUSTODIAL,
		DIRECTOR_TARGET_ENGINEERING,
		DIRECTOR_TARGET_MEDICAL,
		DIRECTOR_TARGET_NONE,
		DIRECTOR_TARGET_SCIENCE,
		DIRECTOR_TARGET_SCIENCE,
		DIRECTOR_TARGET_SECURITY,
		DIRECTOR_TARGET_STATION,
	)

/datum/game_mode/director/pre_setup()
	init_targets()
	return ..()

/datum/game_mode/director/proc/init_targets()
	for(var/target_key in director_target_keys)
		var/director_target = new /datum/director_target(target_key)
		director_targets[target_key] = director_target

/datum/game_mode/director/post_setup(report)
	return ..()

/datum/game_mode/director/process(seconds_per_tick)
	. = ..()

