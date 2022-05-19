/datum/wires/requests_console
	holder_type = /obj/machinery/requests_console
	proper_name = "Requests Console"

/datum/wires/requests_console/New(atom/holder)
	wires = list(
		WIRE_POWER, WIRE_IDSCAN, WIRE_ANNOUNCE, WIRE_PRIORITY, WIRE_EMERGENCY
	)
	add_duds(4)
	..()

/datum/wires/requests_console/interact(mob/user)
	if(!..())
		return FALSE

	var/obj/machinery/requests_console/rc = holder
	return rc.panel_open

/datum/wires/requests_console/get_status()
	var/obj/machinery/requests_console/rc = holder
	var/list/status = list()
	status += "The red light is [!is_cut(WIRE_POWER) ? "lit" : "off"]."
	status += "The green indicator is [!is_cut(WIRE_IDSCAN) ? "on" : "off"]."
	status += "The announcement light is [rc.announce_mod ? (!is_cut(WIRE_ANNOUNCE) ? "on" : "blinking red") : "off"]."
	status += "The orange light is [!is_cut(WIRE_EMERGENCY) ? "on" : "off"]."

	return status

/datum/wires/requests_console/on_cut(wire, mend)
	. = ..()
	var/obj/machinery/requests_console/rc = holder
	switch(wire)
		if(WIRE_EMERGENCY)
			rc.emergency_cut = !mend
			rc.emergency = ""
		if(WIRE_PRIORITY)
			// defines do not reach here :))))
			// #define RC_HACK_PRIORITY_NORMAL 0
			// #define RC_HACK_PRIORITY_CUT 2
			rc.priority_hack_state = mend ? 0 : 2
		if(WIRE_POWER)
			rc.power_cut = !mend
			rc.shock(usr, 50)
		if(WIRE_IDSCAN)
			rc.idscan_cut = !mend
		if(WIRE_ANNOUNCE)
			rc.announce_cut = !mend

/datum/wires/requests_console/on_pulse(wire, user)
	. = ..()
	var/obj/machinery/requests_console/rc = holder
	switch(wire)
		if(WIRE_PRIORITY)
			if(!is_cut(WIRE_PRIORITY))
				// #define RC_HACK_PRIORITY_EXTENDED 1
				rc.priority_hack_state = 1
		if(WIRE_POWER)
			if(prob(25))
				do_sparks(2, TRUE, rc)
