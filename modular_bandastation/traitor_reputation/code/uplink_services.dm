/datum/uplink_tab
	var/name = "Tab"
	var/id = "tab"
	var/icon_state = "tab_default"
	var/list/entries = list()
	var/animation_state = "pulse"
	var/active = FALSE

	proc/Initialize(tab_name, tab_id, tab_icon_state = "tab_default")
		name = tab_name
		id = tab_id
		icon_state = tab_icon_state
		return src

	proc/open()
		active = TRUE
		play_open_animation()
		return src

	proc/play_open_animation()
		var/list/anim = list(
			"tab" = id,
			"icon_state" = icon_state,
			"animation" = animation_state
		)
		return anim

/datum/uplink_service_panel
	var/list/contracts = list()
	var/list/open_events = list()
	var/list/market_items = list()

	proc/add_contract(datum/traitor_contract/C)
		if(C)
			contracts += C
			return TRUE
		return FALSE

	proc/add_event(datum/traitor_event/E)
		if(E)
			open_events += E
			return TRUE
		return FALSE

	proc/add_market_item(item_name)
		if(item_name)
			market_items += item_name
			return TRUE
		return FALSE

	proc/get_active_contract_count()
		return contracts.len

	proc/get_active_event_count()
		return open_events.len

/datum/uplink_controller
	var/list/tabs = list()

	proc/register_tabs(list/tab_list)
		if(islist(tab_list))
			tabs += tab_list
		else if(tab_list)
			tabs += tab_list
		return tabs

	proc/open_tab(tab_id)
		for(var/datum/uplink_tab/T in tabs)
			if(T.id == tab_id)
				T.open()
				return T
		return null

/datum/traitor_uplink_link
	var/datum/traitor_reputation_system/system = null
	var/datum/uplink_controller/uplink = null
	var/list/tabs = list()

	proc/Initialize(datum/traitor_reputation_system/system_input, datum/uplink_controller/uplink_input)
		system = system_input
		uplink = uplink_input
		build_tabs()
		return src

	proc/build_tabs()
		var/datum/uplink_tab/services_tab = new
		services_tab.Initialize("Services", "services", "service_tab")
		var/datum/uplink_tab/reinforcement_tab = new
		reinforcement_tab.Initialize("Reinforcement", "reinforcement", "reinforcement_tab")
		var/datum/uplink_tab/black_market_tab = new
		black_market_tab.Initialize("Black Market", "black_market", "black_market_tab")

		var/datum/uplink_service_panel/service_panel = new
		service_panel.market_items = list("surplus gear", "decoder", "smuggled ammo")
		service_panel.contracts = list()
		service_panel.open_events = list()
		services_tab.entries = list(service_panel)
		reinforcement_tab.entries = list()
		black_market_tab.entries = list(service_panel)

		tabs = list(services_tab, reinforcement_tab, black_market_tab)
		if(uplink)
			uplink.register_tabs(tabs)
		return tabs

	proc/play_tab_animations()
		var/list/anim_states = list()
		for(var/datum/uplink_tab/T in tabs)
			anim_states += T.play_open_animation()
		return anim_states
