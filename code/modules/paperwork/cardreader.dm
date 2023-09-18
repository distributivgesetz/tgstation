/obj/item/cardreader
	name = "card reader"
	desc = "A card reader used to program microchipped authentication cards."
	icon = 'icon/obj/service/bureaucracy.dmi'
	icon_state = "slip"

	/// The currently stored ID card.
	var/obj/item/card/id/stored_id = null
