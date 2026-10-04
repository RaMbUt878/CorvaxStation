/datum/tgui_module/traitor_reputation
	var/datum/traitor_reputation_system/system = null
	var/list/tab_order = list("services", "reinforcement", "black_market")

	proc/Initialize(datum/traitor_reputation_system/system_input)
		system = system_input
		return src

	proc/get_data()
		if(!system)
			return list("error" = "missing_traitor_reputation_system")
		return system.build_tgui_payload()

	proc/get_tabs()
		return tab_order

	proc/activate_tab(tab_id)
		if(tab_id in tab_order)
			return tab_id
		return null

/datum/tgui_panel/traitor_reputation
	var/datum/tgui_module/traitor_reputation/module = null

	proc/Initialize(datum/traitor_reputation_system/system_input)
		module = new
		module.Initialize(system_input)
		return src

	proc/build_view()
		if(!module)
			return list("error" = "missing_module")
		return module.get_data()

	proc/open_for(mob/user)
		if(user)
			return build_view()
		return list("error" = "no_user")

/proc/test_traitor_reputation_modpack()
	var/datum/traitor/traitor = new
	traitor.Initialize("Rambutan")
	traitor.RegisterTraitorUplink()
	var/datum/traitor_reputation_system/system = traitor.reputation_system
	ASSERT(system)
	ASSERT(system.uplink_link)
	ASSERT(system.uplink_link.tabs.len >= 3)
	ASSERT(system.build_tgui_payload()["tabs"][1] == "reinforcement")

	system.add_reputation(150)
	ASSERT(system.get_current_tier()["threshold"] == 150)
	ASSERT(system.get_tier_bonus_tc() == 4)
	ASSERT(system.can_access_agent_chat())

	system.add_reputation(300)
	ASSERT(system.get_current_tier()["threshold"] == 300)
	ASSERT(system.get_tier_bonus_tc() == 6)
	ASSERT(system.can_sabotage_telecomms())

	system.add_reputation(600)
	ASSERT(system.get_current_tier()["threshold"] == 1000)
	ASSERT(system.get_tier_bonus_tc() == 13)
	ASSERT(system.can_convert_crew())
	ASSERT(system.is_priority_target())

	var/rep_gain = system.award_active_goal(350, TRUE)
	ASSERT(rep_gain >= 100 && rep_gain <= 400)

	var/list/bundle = system.create_contract_bundle()
	ASSERT(bundle.len >= 3)

	var/datum/traitor_contract/contract = system.generate_contract("delivery", "engineering")
	ASSERT(contract.reward_tc >= 1 && contract.reward_tc <= 6)
	ASSERT(contract.reputation_reward >= 25)
	ASSERT(system.services.get_active_contract_count() >= 1)

	system.total_tc = 12
	var/list/response = system.request_reinforcement("engineering", 4)
	ASSERT(response["cost_tc"] == 4)
	ASSERT(system.total_tc == 8)
	ASSERT(response["location"] == "engineering")

	var/list/event = system.apply_event_reward("very_important_cargo", TRUE)
	ASSERT(event["result"] == "success")
	ASSERT(event["tc_gained"] == 5)
	ASSERT(event["rep_gained"] == 20)

	var/datum/traitor_event/new_event = system.create_agent_event("very_important_cargo", "Cargo key has been intercepted. Deliver it to the drop site.", "engineering")
	ASSERT(new_event)
	ASSERT(system.services.get_active_event_count() >= 1)

	var/list/animations = system.play_uplink_tab_animations()
	ASSERT(islist(animations) && animations.len >= 3)

	var/datum/uplink_tab/opened = traitor.uplink_controller.open_tab("services")
	ASSERT(opened)
	ASSERT(opened.active)

	world.log << "traitor_reputation_modpack.dm OK"
