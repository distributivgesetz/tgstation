/datum/game_mode/director/admin_panel()
	var/list/html = list()
	html += "<html><head><meta http-equiv='Content-Type' content='text/html; charset=UTF-8'><title>Game Mode Panel</title></head><body>"
	html += "<h1><B>Game Mode Panel - Director</B></h1>"

	html += "Here Be Dragons"

	html += "</body></html>"
	usr << browse(jointext(html), "window=gamemode_panel;size=500x500")



/datum/game_mode/director/Topic(href, list/href_list)
	if (..()) // Sanity, maybe ?
		return
	if(!check_rights(R_ADMIN))
		message_admins("[usr.key] has attempted to override the game mode panel!")
		log_admin("[key_name(usr)] tried to use the game mode panel without authorization.")
		return
