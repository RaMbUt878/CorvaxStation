/datum/traitor_reputation_tier
	var/threshold = 0
	var/bonus_tc = 0
	var/list/unlocks = list()
	var/threat_level = "neutral"

	proc/Initialize(threshold_input, bonus_input, list/unlocks_input = list(), threat_input = "neutral")
		threshold = threshold_input
		bonus_tc = bonus_input
		unlocks = unlocks_input
		threat_level = threat_input
		return src

/datum/traitor_contract
	var/contract_type = ""
	var/reward_tc = 0
	var/reputation_reward = 0
	var/location = "unknown"
	var/description = ""
	var/required_target = ""
	var/required_item = ""
	var/accepted = FALSE

	proc/Initialize(contract_type_input, reward_input, rep_input, location_input = "unknown", required_target_input = "", required_item_input = "")
		contract_type = contract_type_input
		reward_tc = reward_input
		reputation_reward = rep_input
		location = location_input
		required_target = required_target_input
		required_item = required_item_input
		description = "[contract_type] contract for [location]."
		return src

/datum/traitor_event
	var/event_name = ""
	var/description = ""
	var/location = "unknown"
	var/reward_tc = 0
	var/reward_reputation = 0
	var/is_agent_target = TRUE
	var/priority = 0
	var/alerted = FALSE

	proc/Initialize(event_name_input, description_input, location_input = "unknown", reward_tc_input = 0, reward_rep_input = 0, is_agent_target_input = TRUE, priority_input = 0)
		event_name = event_name_input
		description = description_input
		location = location_input
		reward_tc = reward_tc_input
		reward_reputation = reward_rep_input
		is_agent_target = is_agent_target_input
		priority = priority_input
		alerted = TRUE
		return src

/datum/traitor_reinforcement_request
	var/location = "unknown"
	var/cost_tc = 4
	var/requester = "unknown"
	var/created_at = 0
	var/last_update = 0
	var/list/notified_agents = list()
	var/status = "pending"

	proc/Initialize(location_input, cost_input = 4, requester_input = "unknown")
		location = location_input
		cost_tc = cost_input
		requester = requester_input
		created_at = world.time
		last_update = world.time
		status = "requested"
		return src

/datum/traitor_reputation_system
	var/name = "Agent"
	var/reputation = 0
	var/total_tc = 0
	var/earned_tc = 0
	var/spent_tc = 0
	var/completed_goals = 0
	var/successful_infiltrations = 0
	var/active_goal_count = 0
	var/threat_level = "caution"
	var/agent_preview_id = ""
	var/next_random_activity = 0
	var/random_activity_min_delay = 5 MINUTES
	var/random_activity_max_delay = 15 MINUTES
	var/random_activity_chance = 20
	var/datum/uplink_service_panel/services = null
	var/datum/traitor_uplink_link/uplink_link = null
	var/datum/uplink_controller/controller = null
	var/datum/traitor/traitor_owner = null
	var/list/active_contracts = list()
	var/list/active_events = list()

	var/global/list/TRAITOR_REPUTATION_TIERS = list(
		list("threshold" = 150, "bonus_tc" = 4, "unlocks" = list("agent_chat", "first_items"), "threat_level" = "caution"),
		list("threshold" = 300, "bonus_tc" = 6, "unlocks" = list("telecom_sabotage", "threat_rise"), "threat_level" = "warning"),
		list("threshold" = 600, "bonus_tc" = 10, "unlocks" = list("crew_conversion", "bureaucratic_interest"), "threat_level" = "high_alert"),
		list("threshold" = 1000, "bonus_tc" = 13, "unlocks" = list("kill_marker", "evac_override", "department_leak"), "threat_level" = "critical")
	)

	proc/Initialize(datum/traitor/traitor_holder = null, datum/uplink_controller/uplink_controller_input = null)
		name = traitor_holder ? ckey(traitor_holder.name) : "Agent"
		if(!name || name == "")
			name = "Agent"
		services = new
		controller = uplink_controller_input
		if(!controller)
			controller = new
		if(!uplink_link)
			uplink_link = new
			uplink_link.Initialize(src, controller)
		traitor_owner = traitor_holder
		agent_preview_id = traitor_holder ? "" : ""
		schedule_random_activity()
		return src

	proc/AttachToTraitor(datum/traitor/traitor_holder)
		traitor_owner = traitor_holder
		if(!controller)
			controller = new
		if(!uplink_link)
			uplink_link = new
			uplink_link.Initialize(src, controller)
		else if(traitor_holder && traitor_holder.uplink_controller)
			uplink_link.uplink = traitor_holder.uplink_controller
		if(traitor_holder && traitor_holder.uplink_controller)
			controller = traitor_holder.uplink_controller
		if(controller)
			uplink_link.uplink = controller
		schedule_random_activity()
		return uplink_link

	proc/add_reputation(amount)
		if(amount < 0)
			CRASH("Reputation gain must be non-negative.")
		reputation += amount
		update_threat_level()
		return reputation

	proc/get_current_tier()
		var/list/current_tier = TRAITOR_REPUTATION_TIERS[1]
		for(var/i = 1, i <= TRAITOR_REPUTATION_TIERS.len, i++)
			var/list/tier = TRAITOR_REPUTATION_TIERS[i]
			if(reputation >= tier["threshold"])
				current_tier = tier
			else
				break
		return current_tier

	proc/update_threat_level()
		var/list/current_tier = get_current_tier()
		threat_level = current_tier["threat_level"]
		return threat_level

	proc/get_tier_bonus_tc()
		var/list/tier = get_current_tier()
		return tier["bonus_tc"]

	proc/can_access_agent_chat()
		return reputation >= 150

	proc/can_sabotage_telecomms()
		return reputation >= 300

	proc/can_convert_crew()
		return reputation >= 600

	proc/is_priority_target()
		return reputation >= 1000

	proc/award_active_goal(target_difficulty, did_touch = TRUE)
		if(!did_touch)
			return 0
		var/rep_gain = clamp(target_difficulty, 100, 400)
		add_reputation(rep_gain)
		active_goal_count += 1
		completed_goals += 1
		successful_infiltrations += 1
		return rep_gain

	proc/schedule_random_activity()
		if(!traitor_owner)
			return
		if(next_random_activity > world.time)
			return
		next_random_activity = world.time + rand(random_activity_min_delay, random_activity_max_delay)
		addtimer(CALLBACK(src, PROC_REF(spawn_random_activity)), next_random_activity - world.time, TIMER_STOPPABLE)

	proc/spawn_random_activity()
		if(!traitor_owner)
			return
		if(!prob(random_activity_chance))
			schedule_random_activity()
			return

		var/location = pick("engineering", "security", "science", "medical", "cargo", "command", "mining")
		var/contract_type = pick("delivery", "execution", "intel", "retrieval", "sabotage")
		var/roll = rand(1, 100)

		if(roll <= 65)
			generate_contract(contract_type, location)
		else
			var/list/event_templates = list(
				list("name" = "very_important_cargo", "desc" = "Ключ груза пересёк станцию. Восстановите поставку."),
				list("name" = "kill_but_not_finished", "desc" = "Незавершённая операция оставила след. Устраните цель."),
				list("name" = "silent_breach", "desc" = "Оперативная группа оставила мостик в тени. Проверьте сектор."),
			)
			var/list/event_data = pick(event_templates)
			create_agent_event(event_data["name"], event_data["desc"], location)

		schedule_random_activity()

	proc/generate_contract(contract_type, location = "random", required_target = "", required_item = "")
		var/reward = rand(1, 6)
		var/rep_reward = 25 + rand(0, 150)
		var/datum/traitor_contract/contract = new
		contract.Initialize(contract_type, reward, rep_reward, location, required_target, required_item)
		services.add_contract(contract)
		active_contracts += contract
		return contract

	proc/create_agent_event(event_name, description, location = "unknown")
		var/datum/traitor_event/event = new
		event.Initialize(event_name, description, location, 10, 300, TRUE, 5)
		services.add_event(event)
		active_events += event
		return event

	proc/request_reinforcement(location, cost_tc = 4)
		if(cost_tc > total_tc)
			CRASH("Not enough TC to request reinforcement.")
		total_tc -= cost_tc
		spent_tc += cost_tc
		var/datum/traitor_reinforcement_request/request = new
		request.Initialize(location, cost_tc, name)
		return list(
			"cost_tc" = cost_tc,
			"location" = location,
			"notified_agents" = max(1, TRAITOR_REPUTATION_TIERS.len),
			"status" = "reinforcement_requested",
			"request" = request
		)

	proc/apply_event_reward(event_name, success = TRUE)
		var/list/result = list("event" = event_name, "result" = "generic", "tc_gained" = 0, "rep_gained" = 0)

		if(event_name == "very_important_cargo")
			if(success)
				total_tc += 10
				earned_tc += 10
				successful_infiltrations += 1
				add_reputation(300)
				result["result"] = "success"
				result["tc_gained"] = 10
				result["rep_gained"] = 300
				return result
			else
				total_tc += 3
				earned_tc += 3
				result["result"] = "failed"
				result["tc_gained"] = 3
				return result

		if(event_name == "kill_but_not_finished")
			if(success)
				total_tc += 10
				earned_tc += 10
				successful_infiltrations += 1
				add_reputation(300)
				result["result"] = "success"
				result["tc_gained"] = 10
				result["rep_gained"] = 300
				return result
			else
				total_tc += 2
				earned_tc += 2
				add_reputation(50)
				result["result"] = "failed"
				result["tc_gained"] = 2
				result["rep_gained"] = 50
				return result

		add_reputation(50)
		result["rep_gained"] = 50
		return result

	proc/create_contract_bundle()
		var/list/contracts = list(
			generate_contract("delivery", "engineering"),
			generate_contract("execution", "security"),
			generate_contract("intel", "science")
		)
		return contracts

	proc/build_tgui_payload()
		var/list/payload = list(
			"name" = name,
			"player_name" = name,
			"reputation" = reputation,
			"total_tc" = total_tc,
			"earned_tc" = earned_tc,
			"spent_tc" = spent_tc,
			"completed_goals" = completed_goals,
			"successful_infiltrations" = successful_infiltrations,
			"threat_level" = threat_level,
			"agent_preview_id" = agent_preview_id,
			"tier" = get_current_tier(),
			"stats" = list(
				"completed_goals" = completed_goals,
				"successful_infiltrations" = successful_infiltrations,
				"spent_tc" = spent_tc,
				"earned_tc" = earned_tc
			),
			"services" = list(
				"contracts" = services.contracts,
				"events" = services.open_events,
				"market_items" = services.market_items
			),
			"tabs" = list("services", "reinforcement", "black_market")
		)
		return payload

	proc/play_uplink_tab_animations()
		if(uplink_link)
			return uplink_link.play_tab_animations()
		return list()

/datum/traitor
	var/name = "Traitor"
	var/datum/traitor_reputation_system/reputation_system = null
	var/datum/uplink_controller/uplink_controller = null
	var/list/uplink_tabs = list()
	var/has_uplink = TRUE

	proc/Initialize(player_name = "Traitor")
		name = player_name ? ckey(player_name) : "Traitor"
		if(!name || name == "")
			name = "Traitor"
		uplink_controller = new
		reputation_system = new
		reputation_system.Initialize(src, uplink_controller)
		return src

	proc/RegisterTraitorUplink()
		if(!uplink_controller)
			uplink_controller = new
		if(!reputation_system)
			reputation_system = new
			reputation_system.Initialize(src, uplink_controller)
		reputation_system.AttachToTraitor(src)
		uplink_tabs = reputation_system.uplink_link.tabs
		return uplink_tabs

	proc/OpenUplinkTab(tab_id)
		if(uplink_controller)
			return uplink_controller.open_tab(tab_id)
		return null

	proc/GrantReputation(amount)
		if(reputation_system)
			return reputation_system.add_reputation(amount)
		return 0

	proc/RequestReinforcement(location, cost_tc = 4)
		if(reputation_system)
			return reputation_system.request_reinforcement(location, cost_tc)
		return null
