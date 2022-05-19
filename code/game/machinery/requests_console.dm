/******************** Requests Console ********************/
/** Originally written by errorage, updated by: Carn, needs more work though. I just added some security fixes */
/** Consider it reworked! ~ _distrilul */

GLOBAL_LIST_EMPTY(req_console_assistance)
GLOBAL_LIST_EMPTY(req_console_supplies)
GLOBAL_LIST_EMPTY(req_console_information)
GLOBAL_LIST_EMPTY(allConsoles)
GLOBAL_LIST_EMPTY(req_console_ckey_departments)
GLOBAL_LIST_EMPTY(req_announcement_names_used)


#define REQ_SCREEN_MAIN 0
#define REQ_SCREEN_REQ_ASSISTANCE 1
#define REQ_SCREEN_REQ_SUPPLIES 2
#define REQ_SCREEN_RELAY 3
#define REQ_SCREEN_WRITE 4
#define REQ_SCREEN_CHOOSE 5
#define REQ_SCREEN_SENT 6
#define REQ_SCREEN_ERR 7
#define REQ_SCREEN_VIEW_MSGS 8
#define REQ_SCREEN_AUTHENTICATE 9
#define REQ_SCREEN_ANNOUNCE 10

#define RC_HACK_PRIORITY_NORMAL 0
#define RC_HACK_PRIORITY_EXTENDED 1
#define RC_HACK_PRIORITY_CUT 2

// bitflags for preset frequencies, requests consoles speak on the frequencies they are permitted to
#define RC_PRESET_FREQ_COMMAND 1
#define RC_PRESET_FREQ_SECURITY 2
#define RC_PRESET_FREQ_ENGINEERING 4
#define RC_PRESET_FREQ_MEDBAY 8
#define RC_PRESET_FREQ_SCIENCE 16
#define RC_PRESET_FREQ_CARGO 32
#define RC_PRESET_FREQ_AI_PRIVATE 64

#define REQ_EMERGENCY_NONE ""
#define REQ_EMERGENCY_SECURITY "Security"
#define REQ_EMERGENCY_ENGINEERING "Engineering"
#define REQ_EMERGENCY_MEDICAL "Medical"
#define REQ_EMERGENCY_ERROR "Error"

#define ANNOUNCEMENT_NONE "None"
#define ANNOUNCEMENT_CAP "Captain's Desk"
#define ANNOUNCEMENT_HOP "Head of Personnel's Desk"
#define ANNOUNCEMENT_CE "Chief Engineer's Desk"
#define ANNOUNCEMENT_CMO "Chief Medical Officer's Desk"
#define ANNOUNCEMENT_HOS "Head of Security's Desk"
#define ANNOUNCEMENT_QM "Quartermaster's Desk"
#define ANNOUNCEMENT_RD "Research Director's Desk"
#define ANNOUNCEMENT_TCOMS "Telecommunication Admin"
#define ANNOUNCEMENT_BRIDGE "Bridge"

//
//	REQUEST CONSOLE DATA
//

// Message payload for request console requests
/datum/rc_message
	var/message_type // Supplies or Assistance
	var/body // Message Body
	var/sender
	var/time_stamp // current timestamp (do we include timeago?)
	var/priority
	var/authentication // authenticated message
	var/archived = FALSE
	var/response_to

/datum/rc_message/New(msg_type, dep, msg_body = "", msg_priority = REQ_NORMAL_MESSAGE_PRIORITY, msg_person_auth = "Unauthenticated")
	message_type = msg_type
	sender = dep
	body = msg_body
	priority = msg_priority
	authentication = msg_person_auth
	time_stamp = station_time_timestamp()

//
//	REQUEST CONSOLE
//

/obj/machinery/requests_console
	name = "requests console"
	desc = "A console intended to send requests to different departments on the station."
	icon = 'icons/obj/terminals.dmi'
	icon_state = "req_comp_off"
	base_icon_state = "req_comp"
	active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION * 0.15

	// MAPPING DATA

	var/department = "Unknown" //The list of all departments on the station (Determined from this variable on each unit) Set this to the same thing if you want several consoles in one department
	var/departmentType = 0 //bitflag
		// 0 = none (not listed, can only replied to)
		// assistance = 1
		// supplies = 2
		// assistance + supplies = 3
		// --> RELAY ANONYMOUS INFO IS OBSOLETE (even less used than requests consoles, would you believe it)
		// info = 4 -- obsolete
		// assistance + info = 5 -- obsolete
		// supplies + info = 6 -- obsolete
		// assistance + supplies + info = 7 -- obsolete

	var/frequencies = 0

	// HACK STATE

	var/priority_hack_state = RC_HACK_PRIORITY_NORMAL
	var/power_cut = FALSE
	var/emergency_cut = FALSE
	var/announce_cut = FALSE
	var/idscan_cut = FALSE

	// UI DATA

	var/list/datum/rc_message/messages = list() //List of all messages
	var/list/datum/rc_message/sent_messages = list()
	var/newmessagepriority = REQ_NO_NEW_MESSAGE
	var/silent = FALSE // set to 1 for it not to beep all the time
	var/emergency = REQ_EMERGENCY_NONE //If an emergency has been called by this device. Acts as both a cooldown and lets the responder know where it the emergency was triggered from

	// OTHER STATE

	var/obj/item/rc_announce_module/announce_mod
	var/hidden = FALSE
	// Your custom "[announce_mod_name] Announcement:" here!
	// set this to ANNOUNCE_ defines for department head consoles, or make your custom one. idk.
	var/announce_mod_name
	var/announcementCooldown = FALSE
	var/obj/item/radio/Radio

	var/receive_ore_updates = FALSE //If ore redemption machines will send an update when it receives new ores.
	max_integrity = 300
	integrity_failure = 0.25
	armor = list(MELEE = 20, BULLET = 0, LASER = 0, ENERGY = 0, BOMB = 0, BIO = 0, FIRE = 30, ACID = 30)

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/requests_console, 30)

/obj/machinery/requests_console/update_appearance(updates=ALL)
	. = ..()
	if((machine_stat & (NOPOWER | BROKEN)) || panel_open)
		set_light(0)
		return
	set_light(1.4,0.7,"#34D352")//green light

/obj/machinery/requests_console/update_icon_state()
	if(panel_open)
		icon_state = "[base_icon_state]_open"
		return ..()
	icon_state = "[base_icon_state]_off"
	return ..()

/obj/machinery/requests_console/update_overlays()
	. = ..()

	if(panel_open || (machine_stat & (NOPOWER | BROKEN)))
		return

	var/screen_state

	if(emergency != REQ_EMERGENCY_NONE || (newmessagepriority == REQ_EXTREME_MESSAGE_PRIORITY))
		screen_state = "[base_icon_state]3"
	else if(newmessagepriority == REQ_HIGH_MESSAGE_PRIORITY)
		screen_state = "[base_icon_state]2"
	else if(newmessagepriority == REQ_NORMAL_MESSAGE_PRIORITY)
		screen_state = "[base_icon_state]1"
	else
		screen_state = "[base_icon_state]0"

	. += mutable_appearance(icon, screen_state)
	. += emissive_appearance(icon, screen_state, alpha = src.alpha)

/obj/machinery/requests_console/Initialize(mapload)
	. = ..()
	name = "\improper [department] requests console"


	if(mapload && announce_mod_name && announce_mod_name != ANNOUNCEMENT_NONE)
		if(GLOB.req_announcement_names_used.Find(announce_mod_name))
			CRASH("duplicate announce_mod_name [announce_mod_name], mapping issue")
		announce_mod = new(src, announce_mod_name) // heres hoping

	if(!hidden)
		GLOB.allConsoles += src

		if(departmentType)

			if((departmentType & REQ_DEP_TYPE_ASSISTANCE) && !(department in GLOB.req_console_assistance))
				GLOB.req_console_assistance += department

			if((departmentType & REQ_DEP_TYPE_SUPPLIES) && !(department in GLOB.req_console_supplies))
				GLOB.req_console_supplies += department

			if((departmentType & REQ_DEP_TYPE_INFORMATION) && !(department in GLOB.req_console_information))
				GLOB.req_console_information += department

		GLOB.req_console_ckey_departments[ckey(department)] = department

	Radio = new /obj/item/radio(src)
	Radio.set_listening(FALSE)

	wires = new /datum/wires/requests_console(src)

/obj/machinery/requests_console/Destroy()
	QDEL_NULL(Radio)
	QDEL_NULL(announce_mod)
	QDEL_NULL(wires)
	GLOB.allConsoles -= src
	return ..()

/obj/machinery/requests_console/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	if(istype(arrived, /obj/item/rc_announce_module))
		announce_mod = arrived

/obj/machinery/requests_console/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == announce_mod)
		announce_mod = null

// Constructs a rc messaging signal out of ui params
/obj/machinery/requests_console/proc/construct_rc_signal(list/params)
	// validation validation validation
	// addressee
	var/addressee = trim(params["addressee"], 72)

	// message
	var/message_body = trim(params["body"], 1024)

	// priority level
	var/priority_level = text2num(params["priority"])

	if(!priority_level)
		priority_level = REQ_NORMAL_MESSAGE_PRIORITY

	switch(priority_hack_state)
		if(RC_HACK_PRIORITY_NORMAL)
			priority_level = clamp(priority_level, REQ_NORMAL_MESSAGE_PRIORITY, REQ_HIGH_MESSAGE_PRIORITY)
		if(RC_HACK_PRIORITY_EXTENDED)
			priority_level = clamp(priority_level, REQ_NORMAL_MESSAGE_PRIORITY, REQ_EXTREME_MESSAGE_PRIORITY)
		if(RC_HACK_PRIORITY_CUT)
			priority_level = REQ_NORMAL_MESSAGE_PRIORITY

	var/authentication

	// authentication
	// allow people who cut the verification wire to send extreme message without auth, otherwise enforce auth
	if(idscan_cut)
		authentication = "Unknown (Verification Error)"
	else
		var/mob/living/user_mob = usr

		if(!istype(user_mob))
			return

		var/obj/item/card/id/card = user_mob.get_idcard(TRUE)

		if(istype(card) && priority_level == REQ_EXTREME_MESSAGE_PRIORITY)
			return

		if(card)
			authentication = "[card.registered_name] ([card.trim.assignment])"
		else
			authentication = "Unverified"

	// message type
	var/msg_type = params["type"]
	if(msg_type != "Assistance" && msg_type != "Supplies")
		msg_type = "Assistance"

	var/datum/signal/subspace/messaging/rc/signal = new(src, list(
		"rec_dpt" = addressee,
		"send_dpt" = department,
		"message" = message_body,
		"verified" = authentication,
		"priority" = priority_level,
		"type" = msg_type
	))
	return signal

/obj/machinery/requests_console/ui_data(mob/living/user)
	. = ..()
	var/list/data = list()
	data["emergency_dispatch"] = emergency

	var/list/msgs = list()
	for(var/datum/rc_message/msg in messages)
		msgs += list(list(
			"type" = msg.message_type,
			"sender" = msg.sender,
			"body" = msg.body,
			"timestamp" = msg.time_stamp,
			"priority" = msg.priority,
			"authentication" = msg.authentication,
			"archived" = msg.archived
		))
	data["messages"] = msgs

	// ghosts can click rc consoles
	if(istype(user))
		var/obj/item/card/id/card = user.get_idcard(TRUE)
		if(card && card.trim && !idscan_cut)
			data["current_user"] = "[card.registered_name] ([card.trim.assignment])"
			data["can_announce"] = (ACCESS_RC_ANNOUNCE in card?.access)

	data["announce_cooldown"] = announcementCooldown

	data["silent"] = silent
	data["priority_hack_state"] = priority_hack_state
	data["idscan_cut"] = idscan_cut
	data["emergency_cut"] = emergency_cut

	return data

/obj/machinery/requests_console/ui_static_data(mob/user)
	. = ..()
	var/list/static_data = list()
	static_data["rc_supplies"] = GLOB.req_console_supplies
	static_data["rc_assistance"] = GLOB.req_console_assistance
	static_data["announcement_console"] = !isnull(announce_mod)

	return static_data

/obj/machinery/requests_console/ui_act(action, list/params, datum/tgui/ui)
	. = ..()
	if(.)
		return
	add_fingerprint(ui.user)

	switch(action)
	// EMERGENCY
		if("dispatch_emergency")
			if(emergency == REQ_EMERGENCY_NONE && !emergency_cut)
				var/radio_freq
				switch(params["dep"])
					if(REQ_EMERGENCY_SECURITY) //Security
						radio_freq = FREQ_SECURITY
						emergency = REQ_EMERGENCY_SECURITY
					if(REQ_EMERGENCY_ENGINEERING) //Engineering
						radio_freq = FREQ_ENGINEERING
						emergency = REQ_EMERGENCY_ENGINEERING
					if(REQ_EMERGENCY_MEDICAL) //Medical
						radio_freq = FREQ_MEDICAL
						emergency = REQ_EMERGENCY_MEDICAL

				if(radio_freq)
					Radio.set_frequency(radio_freq)
					Radio.talk_into(src,"[emergency] emergency in [department]!!",radio_freq)
					update_appearance()
					addtimer(CALLBACK(src, .proc/clear_emergency), 2 MINUTES)
					updateUsrDialog()
	// SUBMIT REQUEST
		if("submit_new_request")
			var/datum/signal/subspace/messaging/rc/signal = construct_rc_signal(params)
			signal.send_to_receivers()
			updateUsrDialog()
	// SEND ANNOUNCEMENT
		if("send_announcement")
			if(!announce_mod)
				return
			if(announce_cut || idscan_cut)
				return
			if(announcementCooldown)
				return

			var/mob/living/user = usr
			var/obj/item/card/id/id_card = user.get_idcard()

			if(!id_card && !(ACCESS_RC_ANNOUNCE in id_card.access || isAdminGhostAI(usr)))
				return

			var/message = trim(params["message"])
			if(isliving(usr))
				message = user.treat_message(message)
			minor_announce(message, "[announce_mod.announcement_name] Announcement:", html_encode = FALSE)
			GLOB.news_network.submit_article(message, announce_mod.announcement_name, "Station Announcements", null)
			usr.log_talk(message, LOG_SAY, tag="station announcement from [src]")
			message_admins("[ADMIN_LOOKUPFLW(usr)] has made a station announcement from [src] at [AREACOORD(usr)].")
			deadchat_broadcast(" made a station announcement from [span_name("[get_area_name(usr, TRUE)]")].", span_name("[usr.real_name]"), usr, message_type=DEADCHAT_ANNOUNCEMENT)
			announcementCooldown = TRUE
			updateUsrDialog()
			addtimer(CALLBACK(src, .proc/clear_announce_cooldown), 10 SECONDS)
	// ARCHIVE MESSAGE
		if("archive_message")
			if(!isnum(params["id"]))
				return
			var/id = round(params["id"])

			// either i wrote bad ui code or someone is doing a funny
			if(id < 1 || id > length(messages))
				return

			var/datum/rc_message/message = messages[id]
			if(!message)
				return
			message.archived = TRUE
			messages[id] = message
			updateUsrDialog()
	// UNARCHIVE MESSAGE
		if("unarchive_message")
			if(!isnum(params["id"]))
				return
			var/id = round(params["id"])

			// either i wrote bad ui code or someone is doing a funny
			if(id < 1 || id > length(messages))
				return

			var/datum/rc_message/message = messages[id]
			if(!message)
				return
			message.archived = FALSE
			messages[id] = message
			updateUsrDialog()
	// DELETE MESSAGE
		if("delete_message")
			if(!isnum(params["id"]))
				return
			var/id = round(params["id"])

			// either i wrote bad ui code or someone is doing a funny
			if(id < 1 || id > length(messages))
				return
			messages.Cut(id, id + 1)
			updateUsrDialog()
	// SET SILENT
		if("set_silent")
			if(!isnum(params["silent"]))
				return

			var/new_silent = clamp(params["silent"], FALSE, TRUE)

			silent = new_silent
			updateUsrDialog()

/obj/machinery/requests_console/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "RequestsConsole", name)
		ui.open()
	newmessagepriority = REQ_NO_NEW_MESSAGE
	update_appearance()

/obj/machinery/requests_console/ui_status(mob/user)
	. = ..()
	if(panel_open)
		return UI_CLOSE

/obj/machinery/requests_console/proc/clear_announce_cooldown()
	announcementCooldown = FALSE
	updateUsrDialog()

//	var/dat = ""
//	if(!open)
//		switch(screen)
//			if(REQ_SCREEN_MAIN)
//				announceAuth = FALSE
//				if (newmessagepriority == REQ_NORMAL_MESSAGE_PRIORITY)
//					dat += "<div class='notice'>There are new messages</div><BR>"
//				else if (newmessagepriority == REQ_HIGH_MESSAGE_PRIORITY)
//					dat += "<div class='notice'>There are new <b>PRIORITY</b> messages</div><BR>"
//				else if (newmessagepriority == REQ_EXTREME_MESSAGE_PRIORITY)
//					dat += "<div class='notice'>There are new <b>EXTREME PRIORITY</b> messages</div><BR>"
//				dat += "<A href='?src=[REF(src)];setScreen=[REQ_SCREEN_VIEW_MSGS]'>View Messages</A><BR><BR>"
//
//				dat += "<A href='?src=[REF(src)];setScreen=[REQ_SCREEN_REQ_ASSISTANCE]'>Request Assistance</A><BR>"
//				dat += "<A href='?src=[REF(src)];setScreen=[REQ_SCREEN_REQ_SUPPLIES]'>Request Supplies</A><BR>"
//				dat += "<A href='?src=[REF(src)];setScreen=[REQ_SCREEN_RELAY]'>Relay Anonymous Information</A><BR><BR>"
//
//				if(!emergency)
//					dat += "<A href='?src=[REF(src)];emergency=[REQ_EMERGENCY_SECURITY]'>Emergency: Security</A><BR>"
//					dat += "<A href='?src=[REF(src)];emergency=[REQ_EMERGENCY_ENGINEERING]'>Emergency: Engineering</A><BR>"
//					dat += "<A href='?src=[REF(src)];emergency=[REQ_EMERGENCY_MEDICAL]'>Emergency: Medical</A><BR><BR>"
//				else
//					dat += "<B><font color='red'>[emergency] has been dispatched to this location.</font></B><BR><BR>"
//
//				if(announcementConsole)
//					dat += "<A href='?src=[REF(src)];setScreen=[REQ_SCREEN_ANNOUNCE]'>Send Station-wide Announcement</A><BR><BR>"
//				if (silent)
//					dat += "Speaker <A href='?src=[REF(src)];setSilent=0'>OFF</A>"
//				else
//					dat += "Speaker <A href='?src=[REF(src)];setSilent=1'>ON</A>"
//			if(REQ_SCREEN_REQ_ASSISTANCE)
//				dat += "Which department do you need assistance from?<BR><BR>"
//				dat += departments_table(GLOB.req_console_assistance)
//
//			if(REQ_SCREEN_REQ_SUPPLIES)
//				dat += "Which department do you need supplies from?<BR><BR>"
//				dat += departments_table(GLOB.req_console_supplies)
//
//			if(REQ_SCREEN_RELAY)
//				dat += "Which department would you like to send information to?<BR><BR>"
//				dat += departments_table(GLOB.req_console_information)
//
//			if(REQ_SCREEN_SENT)
//				dat += "<span class='good'>Message sent.</span><BR><BR>"
//				dat += "<A href='?src=[REF(src)];setScreen=[REQ_SCREEN_MAIN]'><< Back</A><BR>"
//
//			if(REQ_SCREEN_ERR)
//				dat += "<span class='bad'>An error occurred.</span><BR><BR>"
//				dat += "<A href='?src=[REF(src)];setScreen=[REQ_SCREEN_MAIN]'><< Back</A><BR>"
//
//			if(REQ_SCREEN_VIEW_MSGS)
//				for (var/obj/machinery/requests_console/Console in GLOB.allConsoles)
//					if (Console.department == department)
//						Console.newmessagepriority = REQ_NO_NEW_MESSAGE
//						Console.update_appearance()
//
//				newmessagepriority = REQ_NO_NEW_MESSAGE
//				update_appearance()
//				var/messageComposite = ""
//				for(var/msg in messages) // This puts more recent messages at the *top*, where they belong.
//					messageComposite = "<div class='block'>[msg]</div>" + messageComposite
//				dat += messageComposite
//				dat += "<BR><A href='?src=[REF(src)];setScreen=[REQ_SCREEN_MAIN]'><< Back to Main Menu</A><BR>"
//
//			if(REQ_SCREEN_AUTHENTICATE)
//				dat += "<B>Message Authentication</B><BR><BR>"
//				dat += "<b>Message for [to_department]: </b>[message]<BR><BR>"
//				dat += "<div class='notice'>You may authenticate your message now by scanning your ID or your stamp</div><BR>"
//				dat += "<b>Validated by:</b> [msgVerified ? msgVerified : "<i>Not Validated</i>"]<br>"
//				dat += "<b>Stamped by:</b> [msgStamped ? msgStamped : "<i>Not Stamped</i>"]<br><br>"
//				dat += "<A href='?src=[REF(src)];send=[TRUE]'>Send Message</A><BR>"
//				dat += "<BR><A href='?src=[REF(src)];setScreen=[REQ_SCREEN_MAIN]'><< Discard Message</A><BR>"
//
//			if(REQ_SCREEN_ANNOUNCE)
//				dat += "<h3>Station-wide Announcement</h3>"
//				if(announceAuth)
//					dat += "<div class='notice'>Authentication accepted</div><BR>"
//				else
//					dat += "<div class='notice'>Swipe your card to authenticate yourself</div><BR>"
//				dat += "<b>Message: </b>[message ? message : "<i>No Message</i>"]<BR>"
//				dat += "<A href='?src=[REF(src)];writeAnnouncement=1'>[message ? "Edit" : "Write"] Message</A><BR><BR>"
//				if ((announceAuth || isAdminGhostAI(user)) && message)
//					dat += "<A href='?src=[REF(src)];sendAnnouncement=1'>Announce Message</A><BR>"
//				else
//					dat += "<span class='linkOff'>Announce Message</span><BR>"
//				dat += "<BR><A href='?src=[REF(src)];setScreen=[REQ_SCREEN_MAIN]'><< Back</A><BR>"
//
//		if(!dat)
//			CRASH("No UI for src. Screen var is: [screen]")
//		var/datum/browser/popup = new(user, "req_console", "[department] Requests Console", 450, 440)
//		popup.set_content(dat)
//		popup.open()
//	return

///obj/machinery/requests_console/proc/departments_table(list/req_consoles)
//	var/dat = ""
//	dat += "<table width='100%'>"
//	for(var/req_dpt in req_consoles)
//		if (req_dpt != department)
//			dat += "<tr>"
//			dat += "<td width='55%'>[req_dpt]</td>"
//			dat += "<td width='45%'><A href='?src=[REF(src)];write=[ckey(req_dpt)];priority=[REQ_NORMAL_MESSAGE_PRIORITY]'>Normal</A> <A href='?src=[REF(src)];write=[ckey(req_dpt)];priority=[REQ_HIGH_MESSAGE_PRIORITY]'>High</A>"
//			if(hackState)
//				dat += "<A href='?src=[REF(src)];write=[ckey(req_dpt)];priority=[REQ_EXTREME_MESSAGE_PRIORITY]'>EXTREME</A>"
//			dat += "</td>"
//			dat += "</tr>"
//	dat += "</table>"
//	dat += "<BR><A href='?src=[REF(src)];setScreen=[REQ_SCREEN_MAIN]'><< Back</A><BR>"
//	return dat

// /obj/machinery/requests_console/Topic(href, href_list)
// 	if(..())
// 		return
// 	usr.set_machine(src)
// 	add_fingerprint(usr)

//	if(href_list["write"])
//		to_department = ckey(reject_bad_text(href_list["write"])) //write contains the string of the receiving department's name
//
//		var/new_message = (to_department in GLOB.req_console_ckey_departments) && tgui_input_text(usr, "Write your message", "Awaiting Input")
//		if(new_message)
//			to_department = GLOB.req_console_ckey_departments[to_department]
//			message = new_message
//			screen = REQ_SCREEN_AUTHENTICATE
//			priority = clamp(text2num(href_list["priority"]), REQ_NORMAL_MESSAGE_PRIORITY, REQ_EXTREME_MESSAGE_PRIORITY)
//
//	if(href_list["writeAnnouncement"])
//		var/new_message = reject_bad_text(tgui_input_text(usr, "Write your message", "Awaiting Input"))
//		if(new_message)
//			message = new_message
//			priority = clamp(text2num(href_list["priority"]) || REQ_NORMAL_MESSAGE_PRIORITY, REQ_NORMAL_MESSAGE_PRIORITY, REQ_EXTREME_MESSAGE_PRIORITY)
//		else
//			message = ""
//			announceAuth = FALSE
//			screen = REQ_SCREEN_MAIN
//
//	if(href_list["sendAnnouncement"])
//		if(!announcementConsole)
//			return
//		if(!(announceAuth || isAdminGhostAI(usr)))
//			return
//		if(isliving(usr))
//			var/mob/living/L = usr
//			message = L.treat_message(message)
//		minor_announce(message, "[department] Announcement:", html_encode = FALSE)
//		GLOB.news_network.submit_article(message, department, "Station Announcements", null)
//		usr.log_talk(message, LOG_SAY, tag="station announcement from [src]")
//		message_admins("[ADMIN_LOOKUPFLW(usr)] has made a station announcement from [src] at [AREACOORD(usr)].")
//		deadchat_broadcast(" made a station announcement from [span_name("[get_area_name(usr, TRUE)]")].", span_name("[usr.real_name]"), usr, message_type=DEADCHAT_ANNOUNCEMENT)
//		announceAuth = FALSE
//		message = ""
//		screen = REQ_SCREEN_MAIN

//	if(href_list["emergency"])
//		if(!emergency)
//			var/radio_freq
//			switch(text2num(href_list["emergency"]))
//				if(REQ_EMERGENCY_SECURITY) //Security
//					radio_freq = FREQ_SECURITY
//					emergency = "Security"
//				if(REQ_EMERGENCY_ENGINEERING) //Engineering
//					radio_freq = FREQ_ENGINEERING
//					emergency = "Engineering"
//				if(REQ_EMERGENCY_MEDICAL) //Medical
//					radio_freq = FREQ_MEDICAL
//					emergency = "Medical"
//			if(radio_freq)
//				Radio.set_frequency(radio_freq)
//				Radio.talk_into(src,"[emergency] emergency in [department]!!",radio_freq)
//				update_appearance()
//				addtimer(CALLBACK(src, .proc/clear_emergency), 5 MINUTES)

//	if(href_list["send"] && message && to_department && priority)
//
//		var/radio_freq
//		switch(ckey(to_department))
//			if("bridge")
//				radio_freq = FREQ_COMMAND
//			if("medbay")
//				radio_freq = FREQ_MEDICAL
//			if("science")
//				radio_freq = FREQ_SCIENCE
//			if("engineering")
//				radio_freq = FREQ_ENGINEERING
//			if("security")
//				radio_freq = FREQ_SECURITY
//			if("cargobay", "mining")
//				radio_freq = FREQ_SUPPLY
//
//		var/datum/signal/subspace/messaging/rc/signal = new(src, list(
//			"sender" = department,
//			"rec_dpt" = to_department,
//			"send_dpt" = department,
//			"message" = message,
//			"verified" = msgVerified,
//			"stamped" = msgStamped,
//			"priority" = priority,
//			"notify_freq" = radio_freq
//		))
//		signal.send_to_receivers()
//
//		screen = signal.data["done"] ? REQ_SCREEN_SENT : REQ_SCREEN_ERR
//
//	//Handle screen switching
//	if(href_list["setScreen"])
//		var/set_screen = clamp(text2num(href_list["setScreen"]) || 0, REQ_SCREEN_MAIN, REQ_SCREEN_ANNOUNCE)
//		switch(set_screen)
//			if(REQ_SCREEN_MAIN)
//				to_department = ""
//				msgVerified = ""
//				msgStamped = ""
//				message = ""
//				priority = -1
//			if(REQ_SCREEN_ANNOUNCE)
//				if(!announcementConsole)
//					return
//		screen = set_screen
//
//	//Handle silencing the console
//	if(href_list["setSilent"])
//		silent = text2num(href_list["setSilent"]) ? TRUE : FALSE
//
//	updateUsrDialog()

/obj/machinery/requests_console/say_mod(input, list/message_mods = list())
	if(spantext_char(input, "!", -3))
		return "blares"
	else
		. = ..()

/obj/machinery/requests_console/proc/compile_frequency_list()
	var/list/freqs = list()

	if(RC_PRESET_FREQ_COMMAND in frequencies)
		freqs.Add(FREQ_COMMAND)
	if(RC_PRESET_FREQ_SECURITY in frequencies)
		freqs.Add(FREQ_SECURITY)
	if(RC_PRESET_FREQ_MEDBAY in frequencies)
		freqs.Add(FREQ_MEDICAL)
	if(RC_PRESET_FREQ_CARGO in frequencies)
		freqs.Add(FREQ_SUPPLY)
	if(RC_PRESET_FREQ_SCIENCE in frequencies)
		freqs.Add(FREQ_SCIENCE)
	if(RC_PRESET_FREQ_ENGINEERING in frequencies)
		freqs.Add(FREQ_ENGINEERING)
	if(RC_PRESET_FREQ_AI_PRIVATE in frequencies)
		freqs.Add(FREQ_AI_PRIVATE)

	return freqs

/obj/machinery/requests_console/proc/clear_emergency(responder_name)
	if(responder_name)
		var/radio_freq
		switch(emergency)
			if(REQ_EMERGENCY_MEDICAL)
				radio_freq = FREQ_MEDICAL
			if(REQ_EMERGENCY_SECURITY)
				radio_freq = FREQ_SECURITY
			if(REQ_EMERGENCY_ENGINEERING)
				radio_freq = FREQ_ENGINEERING
		Radio.talk_into(src, "[responder_name] has responded to the emergency.", radio_freq)

	to_chat(usr, span_notice("You clear the emergency alert on \the [department] request console."))
	playsound(src, 'sound/machines/twobeep_high.ogg', 50, TRUE)
	emergency = REQ_EMERGENCY_NONE
	update_appearance()

//from message_server.dm: Console.createmessage(data["sender"], data["send_dpt"], data["message"], data["verified"], data["stamped"], data["priority"], data["notify_freq"])
/obj/machinery/requests_console/proc/createmessage(source_department, type, message, verified, priority, radio_freq)
//	var/linkedsender
//
//	var/sending = "[message]<br>"
//	if(msgVerified)
//		sending = "[sending][msgVerified]<br>"
//	if(msgStamped)
//		sending = "[sending][msgStamped]<br>"
//
//	linkedsender = source_department ? "<a href='?src=[REF(src)];write=[ckey(source_department)]'>[source_department]</a>" : (source || "unknown")
//
//	var/authentic = msgVerified && " (Authenticated)"
	var/alert = "Message from [source_department]"
	var/silenced = silent

	var/datum/rc_message/msg = new(type, source_department, message, priority, verified)

	switch(priority)
		if(REQ_NORMAL_MESSAGE_PRIORITY)
			if(newmessagepriority < REQ_NORMAL_MESSAGE_PRIORITY)
				newmessagepriority = REQ_NORMAL_MESSAGE_PRIORITY
				update_appearance()

		if(REQ_HIGH_MESSAGE_PRIORITY)
			alert = "PRIORITY " + alert
			if(newmessagepriority < REQ_HIGH_MESSAGE_PRIORITY)
				newmessagepriority = REQ_HIGH_MESSAGE_PRIORITY
				update_appearance()

		if(REQ_EXTREME_MESSAGE_PRIORITY)
			alert = "EXTREME PRIORITY " + alert
			silenced = FALSE
			if(newmessagepriority < REQ_EXTREME_MESSAGE_PRIORITY)
				newmessagepriority = REQ_EXTREME_MESSAGE_PRIORITY
				update_appearance()

	messages += msg

	if(!silenced)
		playsound(src, 'sound/machines/twobeep_high.ogg', 50, TRUE)
		say(alert)

	if(frequencies)
		var/frequency_list = compile_frequency_list()
		for(var/frequency in frequency_list)
			Radio.talk_into(src, "[alert]: <i>[message]</i>", frequency)

// yoinked from power/apc.dm
/obj/machinery/requests_console/proc/shock(mob/user, prb)
	if(!prob(prb))
		return FALSE
	do_sparks(5, TRUE, src)
	if(isalien(user))
		return FALSE
	if(electrocute_mob(user, src, src, 1, TRUE))
		return TRUE
	else
		return FALSE

/obj/machinery/requests_console/screwdriver_act(mob/living/user, obj/item/tool)
	if(announce_cut && panel_open && announce_mod)
		tool.play_tool_sound(src)
		user.put_in_hands(announce_mod)
		to_chat(user, span_notice("You remove the announcement module from \the [name]."))
		return TRUE
	tool.play_tool_sound(src)
	panel_open = !panel_open
	to_chat(user, span_notice("You [panel_open ? "open" : "close"] the maintenance cover."))
	update_appearance()
	return TRUE

/obj/machinery/requests_console/wrench_act(mob/living/user, obj/item/tool)
	if(panel_open && !announce_mod)
		tool.play_tool_sound(src)
		if(tool.use_tool(src, user, 50))
			playsound(loc, 'sound/items/deconstruct.ogg', 50, TRUE)
			new /obj/item/wallframe/requests_console(loc)
			qdel(src)
		return TRUE
	. = ..()

/obj/machinery/requests_console/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		new /obj/item/stack/sheet/iron(loc, 2)
		new /obj/item/shard(loc)
	qdel(src)

/obj/machinery/requests_console/attackby(obj/item/O, mob/user, params)
	var/obj/item/card/id/card = O.GetID()
	if(card)
		// check if id trim is valid
		var/datum/id_trim/job/trim_job = card.trim
		if(istype(trim_job))
			switch(emergency)
				if(REQ_EMERGENCY_MEDICAL)
					if(trim_job.job.departments_list.Find(/datum/job_department/medical))
						clear_emergency(card.registered_name)
				if(REQ_EMERGENCY_SECURITY)
					if(trim_job.job.departments_list.Find(/datum/job_department/security))
						clear_emergency(card.registered_name)
				if(REQ_EMERGENCY_ENGINEERING)
					if(trim_job.job.departments_list.Find(/datum/job_department/engineering))
						clear_emergency(card.registered_name)
			return
	else if(is_wire_tool(O) && panel_open)
		wires.interact(user)
		return
	else if(istype(O, /obj/item/rc_announce_module) && panel_open)
		var/obj/item/rc_announce_module/module = O
		if(announce_mod)
			to_chat(user, span_warning("There is already an announcement module installed in \the [name]!"))
			return

		if(module.announcement_name == ANNOUNCEMENT_NONE)
			to_chat(user, span_warning("This announcement module is not set to anything!"))
			return

		if(!user.transferItemToLoc(module, src))
			return

		if(announce_cut)
			wires.cut(WIRE_ANNOUNCE) // reverse cut
		to_chat(user, span_notice("You plug the announcement module into \the [name]."))
		return

	return ..()

/obj/machinery/requests_console/take_damage(damage_amount, damage_type, damage_flag, sound_effect, attack_dir, armour_penetration)
	. = ..()
	update_appearance()

/obj/item/rc_announce_module
	name = "requests console announcement module"
	desc = "A dongle which holds encryption keys for the station's onboard announcement systems. It can be plugged into requests consoles."
	icon = 'icons/obj/stock_parts.dmi'
	icon_state = "rc_dongle"
	inhand_icon_state = "electronic"
	lefthand_file = 'icons/mob/inhands/misc/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/misc/devices_righthand.dmi'
	custom_materials = list(/datum/material/iron = 200, /datum/material/silver = 150, /datum/material/diamond = 50)
	w_class = WEIGHT_CLASS_SMALL

	var/announcement_name = ANNOUNCEMENT_NONE

/obj/item/rc_announce_module/New(loc, name)
	. = ..()
	set_announce(name)

/obj/item/rc_announce_module/Destroy(force)
	. = ..()
	reset_name()

/obj/item/rc_announce_module/proc/reset_name()
	if(announcement_name == ANNOUNCEMENT_NONE)
		return
	if(GLOB.req_announcement_names_used.Find(announcement_name))
		GLOB.req_announcement_names_used -= announcement_name
	announcement_name = ANNOUNCEMENT_NONE

/obj/item/rc_announce_module/attackby(obj/item/attacking_item, mob/user, params)
	var/obj/item/card/id/card = attacking_item.GetID()
	if(card)
		if(!(ACCESS_RC_ANNOUNCE in card.access))
			to_chat(user, span_warning("You do not have access to change the announcement type!"))
			return

		// filter out used names
		var/list/base_announcement_names = list(
			ANNOUNCEMENT_CAP, ANNOUNCEMENT_HOP, ANNOUNCEMENT_CE,
			ANNOUNCEMENT_CMO, ANNOUNCEMENT_HOS, ANNOUNCEMENT_QM,
			ANNOUNCEMENT_RD, ANNOUNCEMENT_TCOMS, ANNOUNCEMENT_BRIDGE
		)

		// filter list based on what's taken
		base_announcement_names.Remove(GLOB.req_announcement_names_used)

		// return if every name is used
		if(!length(base_announcement_names))
			to_chat(user, span_warning("All announcement names are used!"))
			return

		var/announce_type = tgui_input_list(user, "Select an announcement type", "Announcement Type", base_announcement_names)

		if(!set_announce(announce_type))
			to_chat(user, span_warning("This announcement name is unavailable!"))
			return

		to_chat(user, span_notice("You set the announcement module to \"[announce_type]\"."))
		return
	. = ..()

/obj/item/rc_announce_module/examine(mob/user)
	. = ..()
	. += span_notice("The announcement module is set to \"[announcement_name]\".")
	if(announcement_name != ANNOUNCEMENT_NONE)
		. += span_notice("Alt-Click to reset the name.")
	. += span_notice("Swipe a card with request console announcement access to change it.")

/obj/item/rc_announce_module/AltClick(mob/user)
	. = ..()
	if(announcement_name == ANNOUNCEMENT_NONE)
		return
	reset_name()
	to_chat(user, span_notice("You reset the announcement module."))

/obj/item/rc_announce_module/proc/set_announce(name)
	if(!name || name == ANNOUNCEMENT_NONE)
		return FALSE

	if(GLOB.req_announcement_names_used.Find(name))
		return FALSE

	reset_name()
	GLOB.req_announcement_names_used += name
	announcement_name = name

	return TRUE

/obj/item/wallframe/requests_console
	name = "requests console frame"
	desc = "Used to build requests consoles, secure to the wall."
	icon_state = "requestsconsole"
	custom_materials = list(/datum/material/iron=14000, /datum/material/glass=8000)
	result_path = /obj/machinery/requests_console
	pixel_shift = 30

#undef ANNOUNCEMENT_NONE
#undef ANNOUNCEMENT_CAP
#undef ANNOUNCEMENT_HOP
#undef ANNOUNCEMENT_CE
#undef ANNOUNCEMENT_CMO
#undef ANNOUNCEMENT_HOS
#undef ANNOUNCEMENT_QM
#undef ANNOUNCEMENT_RD
#undef ANNOUNCEMENT_TCOMS
#undef ANNOUNCEMENT_BRIDGE

#undef REQ_EMERGENCY_NONE
#undef REQ_EMERGENCY_SECURITY
#undef REQ_EMERGENCY_ENGINEERING
#undef REQ_EMERGENCY_MEDICAL

#undef RC_HACK_PRIORITY_NORMAL
#undef RC_HACK_PRIORITY_EXTENDED
#undef RC_HACK_PRIORITY_CUT

#undef RC_PRESET_FREQ_COMMAND
#undef RC_PRESET_FREQ_SECURITY
#undef RC_PRESET_FREQ_ENGINEERING
#undef RC_PRESET_FREQ_MEDBAY
#undef RC_PRESET_FREQ_SCIENCE
#undef RC_PRESET_FREQ_CARGO
#undef RC_PRESET_FREQ_AI_PRIVATE

#undef REQ_SCREEN_MAIN
#undef REQ_SCREEN_REQ_ASSISTANCE
#undef REQ_SCREEN_REQ_SUPPLIES
#undef REQ_SCREEN_RELAY
#undef REQ_SCREEN_WRITE
#undef REQ_SCREEN_CHOOSE
#undef REQ_SCREEN_SENT
#undef REQ_SCREEN_ERR
#undef REQ_SCREEN_VIEW_MSGS
#undef REQ_SCREEN_AUTHENTICATE
#undef REQ_SCREEN_ANNOUNCE
