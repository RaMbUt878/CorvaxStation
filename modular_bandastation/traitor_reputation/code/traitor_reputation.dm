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
	var/required_role = ""
	var/required_item = null
	var/item_tier = ""
	var/tc_drop_chance = 0
	var/contract_id = ""
	var/accepted = FALSE

	proc/Initialize(contract_type_input, reward_input, rep_input, location_input = "unknown", required_target_input = "", required_item_input = "", required_role_input = "")
		contract_type = contract_type_input
		reward_tc = reward_input
		reputation_reward = rep_input
		location = location_input
		required_target = required_target_input
		required_role = required_role_input
		required_item = required_item_input
		description = "Контракт «[contract_type]» для сектора «[location]»."
		return src

/datum/traitor_event
	var/event_id = ""
	var/event_name = ""
	var/description = ""
	var/location = "unknown"
	var/reward_tc = 0
	var/reward_reputation = 0
	var/tc_drop_chance = 100
	var/is_agent_target = TRUE
	var/priority = 0
	var/alerted = FALSE

	proc/Initialize(event_name_input, description_input, location_input = "unknown", reward_tc_input = 0, reward_rep_input = 0, is_agent_target_input = TRUE, priority_input = 0, event_id_input = "", tc_drop_chance_input = 100)
		event_id = event_id_input || REF(src)
		event_name = event_name_input
		description = description_input
		location = location_input
		reward_tc = reward_tc_input
		reward_reputation = reward_rep_input
		tc_drop_chance = tc_drop_chance_input
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

/proc/get_traitor_uplink_minimum_reputation(datum/uplink_item/item)
	if(!(item.purchasable_from & UPLINK_TRAITORS))
		return 0
	var/item_cost = initial(item.cost)
	if(item_cost >= 30)
		return 1000
	if(item_cost >= 20)
		return 600
	if(item_cost >= 10)
		return 300
	if(item_cost >= 5)
		return 150
	return 0

/datum/traitor_reputation_system
	var/name = "Агент"
	var/reputation = 0
	var/passive_reputation_gain = 5
	var/total_tc = 0
	var/earned_tc = 0
	var/spent_tc = 0
	var/completed_goals = 0
	var/successful_infiltrations = 0
	var/active_goal_count = 0
	var/threat_level = "caution"
	var/agent_preview_id = ""
	var/next_random_activity = 0
	var/next_agent_chat_message = 0
	var/random_activity_timer
	var/datum/antagonist/traitor/antagonist_owner
	var/datum/uplink_handler/uplink_handler
	var/random_activity_min_delay = 3 MINUTES
	var/random_activity_max_delay = 5 MINUTES
	var/datum/uplink_service_panel/services = null
	var/datum/traitor_uplink_link/uplink_link = null
	var/datum/uplink_controller/controller = null
	var/datum/traitor/traitor_owner = null
	var/list/active_contracts = list()
	var/list/active_events = list()
	var/datum/traitor_contract/rotating_contract

	proc/can_purchase_uplink_item(mob/user, datum/uplink_item/item)
		var/minimum_reputation = get_traitor_uplink_minimum_reputation(item)
		return reputation >= minimum_reputation

	var/global/list/TRAITOR_REPUTATION_TIERS = list(
		list("threshold" = 150, "bonus_tc" = 4, "unlocks" = list("agent_chat", "first_items"), "threat_level" = "caution"),
		list("threshold" = 300, "bonus_tc" = 6, "unlocks" = list("telecom_sabotage", "threat_rise"), "threat_level" = "warning"),
		list("threshold" = 600, "bonus_tc" = 10, "unlocks" = list("crew_conversion", "bureaucratic_interest"), "threat_level" = "high_alert"),
		list("threshold" = 1000, "bonus_tc" = 13, "unlocks" = list("kill_marker", "evac_override", "department_leak"), "threat_level" = "critical")
	)

	proc/Initialize(datum/traitor/traitor_holder = null, datum/uplink_controller/uplink_controller_input = null)
		name = traitor_holder ? ckey(traitor_holder.name) : "Agent"
		if(!name || name == "")
			name = "Агент"
		services = new
		controller = uplink_controller_input
		if(!controller)
			controller = new
		if(!uplink_link)
			uplink_link = new
			uplink_link.Initialize(src, controller)
		traitor_owner = traitor_holder
		agent_preview_id = traitor_holder ? "" : ""
		rotating_contract = generate_item_contract()
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
		var/old_reputation = reputation
		reputation += amount
		update_threat_level()
		for(var/list/tier as anything in TRAITOR_REPUTATION_TIERS)
			var/threshold = tier["threshold"]
			if(old_reputation < threshold && reputation >= threshold)
				announce_reputation_tier(threshold)
				if(uplink_handler)
					var/tier_bonus = tier["bonus_tc"]
					uplink_handler.add_telecrystals(tier_bonus)
					earned_tc += tier_bonus
		uplink_handler?.on_update()
		return reputation

	proc/announce_reputation_tier(threshold)
		var/mob/living/agent = antagonist_owner?.owner?.current
		var/species = "не установлена"
		var/agent_gender = "не установлен"
		var/department = "не установлен"
		var/agent_job = "не установлена"
		var/agent_name = "не установлено"

		if(ishuman(agent))
			var/mob/living/carbon/human/human_agent = agent
			species = human_agent.dna?.species?.name || species
			if(human_agent.gender == MALE)
				agent_gender = "мужской"
			else if(human_agent.gender == FEMALE)
				agent_gender = "женский"
		if(agent?.mind?.assigned_role)
			var/datum/job/agent_role = agent.mind.assigned_role
			var/datum/job_department/department_type = agent_role.departments_list?[1]
			if(department_type)
				department = department_type::department_name
			agent_job = job_title_ru(agent_role.title)
		if(agent)
			agent_name = agent.real_name

		var/message
		switch(threshold)
			if(150)
				message = "По неофициальным данным, на борту выявлена потенциальная угроза. Предполагаемая раса: [species]. Отдел кадров и Служба безопасности проверяют ситуацию."
			if(300)
				message = "Угроза подтверждена. На борту находится агент враждующей организации. Предполагаемая раса: [species], пол: [agent_gender]. Службам станции рекомендуется сохранять бдительность."
			if(600)
				message = "Активность вражеского агента возросла. Предполагаемая раса: [species], пол: [agent_gender]. Агент числится в отделе «[department]» на должности «[agent_job]». Службе безопасности поручено усилить контроль."
			if(1000)
				message = "Зафиксирована критическая угроза. Предполагаемая личность агента: [agent_name]. Его раса: [species], пол: [agent_gender], отдел: «[department]», должность: «[agent_job]». Экипажу следует передать эту информацию Службе безопасности и выполнять распоряжения командования."
		if(message)
			minor_announce(message, "Центральное командование", TRUE)

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
		if(!traitor_owner && !antagonist_owner)
			return
		if(next_random_activity > world.time)
			return
		next_random_activity = world.time + rand(random_activity_min_delay, random_activity_max_delay)
		random_activity_timer = addtimer(CALLBACK(src, PROC_REF(spawn_random_activity)), next_random_activity - world.time, TIMER_STOPPABLE)

	proc/spawn_random_activity()
		random_activity_timer = null
		if(!traitor_owner && !antagonist_owner)
			return
		if(rotating_contract)
			remove_contract(rotating_contract)
		if(prob(40))
			rotating_contract = generate_item_contract()
		else
			var/location = pick("engineering", "security", "science", "medical", "cargo", "command", "mining")
			var/contract_type = pick("delivery", "execution", "intel", "retrieval", "sabotage")
			rotating_contract = generate_contract(contract_type, location)

		schedule_random_activity()

	proc/stop_random_activity()
		if(random_activity_timer)
			deltimer(random_activity_timer)
			random_activity_timer = null
		next_random_activity = 0

	proc/generate_contract(contract_type, location = "random", required_target = "", required_item = "")
		var/reward = rand(1, 6)
		var/rep_reward = 25 + rand(0, 150)
		var/datum/traitor_contract/contract = new
		contract.Initialize(contract_type, reward, rep_reward, location, required_target, required_item)
		contract.contract_id = REF(contract)
		services.add_contract(contract)
		active_contracts += contract
		uplink_handler?.on_update()
		return contract

	proc/generate_item_contract()
		for(var/datum/traitor_contract/existing_contract as anything in active_contracts)
			if(existing_contract.contract_type == "item_retrieval" && !existing_contract.accepted)
				return existing_contract

		var/round_time = world.time - SSticker.round_start_time
		var/item_tier = "easy"
		if(round_time >= 30 MINUTES && prob(20))
			item_tier = "hard"
		else if(round_time >= 15 MINUTES && prob(40))
			item_tier = "medium"

		var/list/item_types
		var/list/item_names
		var/reward_min
		var/reward_max
		var/tc_min
		var/tc_max
		switch(item_tier)
			if("easy")
				item_types = list(
					/obj/item/paper,
					/obj/item/pen,
					/obj/item/soap,
					/obj/item/flashlight,
					/obj/item/crowbar,
				)
				item_names = list("лист бумаги", "ручка", "мыло", "фонарь", "лом")
				reward_min = 5
				reward_max = 10
				tc_min = 1
				tc_max = 2
			if("medium")
				item_types = list(
					/obj/item/wrench,
					/obj/item/screwdriver,
					/obj/item/hand_labeler,
					/obj/item/camera,
					/obj/item/weldingtool,
				)
				item_names = list("гаечный ключ", "отвёртка", "маркиратор", "фотоаппарат", "сварочный аппарат")
				reward_min = 15
				reward_max = 25
				tc_min = 2
				tc_max = 3
			if("hard")
				item_types = list(
					/obj/item/multitool,
					/obj/item/stack/sheet/plasteel,
				)
				item_names = list("мультитул", "лист пластали")
				reward_min = 35
				reward_max = 50
				tc_min = 4
				tc_max = 5

		var/item_index = rand(1, length(item_types))
		var/required_item_type = item_types[item_index]
		var/item_name = item_names[item_index]
		var/datum/traitor_contract/contract = generate_contract(
			"item_retrieval",
			"station",
			item_name,
			required_item_type,
		)
		contract.item_tier = item_tier
		contract.reward_tc = rand(tc_min, tc_max)
		contract.tc_drop_chance = rand(30, 45)
		contract.reputation_reward = rand(reward_min, reward_max)
		contract.description = "Добыть [item_name] и сдать через аплинк. Предмет будет изъят."
		uplink_handler?.on_update()
		return contract

	proc/complete_item_contract(mob/living/user, contract_id)
		if(!user || user.stat == DEAD || !user.mind?.has_antag_datum(/datum/antagonist/traitor))
			return FALSE
		var/datum/traitor_contract/item_contract
		for(var/datum/traitor_contract/contract as anything in active_contracts)
			if(contract.contract_type == "item_retrieval" && contract.contract_id == contract_id && !contract.accepted)
				item_contract = contract
				break
		if(!item_contract)
			return FALSE

		var/obj/item/turned_in_item
		for(var/obj/item/item as anything in user.get_all_contents())
			if(istype(item, item_contract.required_item))
				turned_in_item = item
				break
		if(!turned_in_item)
			to_chat(user, span_warning("У вас нет предмета для этого контракта."))
			return FALSE

		item_contract.accepted = TRUE
		qdel(turned_in_item)
		var/tc_reward = prob(item_contract.tc_drop_chance) ? item_contract.reward_tc : 0
		if(tc_reward)
			uplink_handler?.add_telecrystals(tc_reward)
			total_tc += tc_reward
			earned_tc += tc_reward
		add_reputation(item_contract.reputation_reward)
		remove_contract(item_contract)
		to_chat(user, span_notice("Контракт выполнен. Награда: [item_contract.reputation_reward] REP[tc_reward ? " и [tc_reward] TC" : "; в этот раз без TC"]."))
		return TRUE

	proc/create_agent_event(event_name, description, location = "unknown", event_id = "", reward_tc = 10, reward_reputation = 300, tc_drop_chance = 100)
		var/datum/traitor_event/event = new
		event.Initialize(event_name, description, location, reward_tc, reward_reputation, TRUE, 5, event_id, tc_drop_chance)
		services.add_event(event)
		active_events += event
		uplink_handler?.on_update()
		return event

	proc/complete_assassination(datum/traitor_contract/contract, smited = FALSE)
		if(!contract || contract.accepted)
			return FALSE
		contract.accepted = TRUE
		var/tc_reward = smited ? 10 : (prob(contract.tc_drop_chance) ? contract.reward_tc : 0)
		if(tc_reward)
			uplink_handler?.add_telecrystals(tc_reward)
			total_tc += tc_reward
			earned_tc += tc_reward
		add_reputation(contract.reputation_reward)
		remove_contract(contract)
		if(antagonist_owner?.owner?.current)
			to_chat(antagonist_owner.owner.current, span_notice("Цель устранена. Награда: [contract.reputation_reward] REP[tc_reward ? " и [tc_reward] TC" : "; в этот раз без TC"]."))
		return tc_reward

	proc/remove_contract(datum/traitor_contract/contract)
		if(!contract)
			return FALSE
		active_contracts -= contract
		services.contracts -= contract
		if(contract == rotating_contract)
			rotating_contract = null
		uplink_handler?.on_update()
		return TRUE

	proc/remove_event(datum/traitor_event/event)
		if(!event)
			return FALSE
		active_events -= event
		services.open_events -= event
		qdel(event)
		uplink_handler?.on_update()
		return TRUE

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
				total_tc += 5
				earned_tc += 5
				uplink_handler?.add_telecrystals(5)
				successful_infiltrations += 1
				add_reputation(20)
				result["result"] = "success"
				result["tc_gained"] = 5
				result["rep_gained"] = 20
				return result
			else
				result["result"] = "failed"
				return result

		if(event_name == "kill_but_not_finished")
			if(success)
				var/tc_reward = prob(35) ? 5 : 0
				if(tc_reward)
					total_tc += tc_reward
					earned_tc += tc_reward
					uplink_handler?.add_telecrystals(tc_reward)
				successful_infiltrations += 1
				add_reputation(20)
				result["result"] = "success"
				result["tc_gained"] = tc_reward
				result["rep_gained"] = 20
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
		var/list/tier_data = list()
		var/list/chat_messages = list()
		if(can_access_agent_chat())
			for(var/list/chat_message as anything in GLOB.traitor_agent_chat_messages)
				if(chat_message["round_start_time"] != SSticker.round_start_time)
					continue
				chat_messages += list(list(
					"sender" = chat_message["sender"],
					"message" = chat_message["message"],
					"timestamp" = chat_message["timestamp"],
					"outgoing" = chat_message["sender"] == name,
				))
		for(var/list/tier as anything in TRAITOR_REPUTATION_TIERS)
			tier_data += list(list(
				"threshold" = tier["threshold"],
				"bonus_tc" = tier["bonus_tc"],
				"unlocks" = tier["unlocks"],
				"threat_level" = tier["threat_level"],
			))

		var/list/contract_data = list()
		for(var/datum/traitor_contract/contract as anything in active_contracts)
			contract_data += list(list(
				"type" = contract.contract_type,
				"description" = contract.description,
				"location" = contract.location,
				"target" = contract.required_target,
				"role" = contract.required_role,
				"item_tier" = contract.item_tier,
				"tc_drop_chance" = contract.tc_drop_chance,
				"contract_id" = contract.contract_id,
				"can_turn_in" = contract.contract_type == "item_retrieval",
				"reward_tc" = contract.reward_tc,
				"reputation_reward" = contract.reputation_reward,
			))

		var/list/event_data = list()
		for(var/datum/traitor_event/event as anything in active_events)
			event_data += list(list(
				"id" = event.event_id,
				"name" = event.event_name,
				"description" = event.description,
				"location" = event.location,
				"reward_tc" = event.reward_tc,
				"reward_reputation" = event.reward_reputation,
				"tc_drop_chance" = event.tc_drop_chance,
			))

		var/list/payload = list(
			"name" = name,
			"player_name" = name,
			"reputation" = reputation,
			"passive_reputation_gain" = passive_reputation_gain,
			"total_tc" = total_tc,
			"earned_tc" = earned_tc,
			"spent_tc" = spent_tc,
			"completed_goals" = completed_goals,
			"successful_infiltrations" = successful_infiltrations,
			"threat_level" = threat_level,
			"agent_preview_id" = agent_preview_id,
			"tier" = get_current_tier(),
			"tiers" = tier_data,
			"stats" = list(
				"completed_goals" = completed_goals,
				"successful_infiltrations" = successful_infiltrations,
				"spent_tc" = spent_tc,
				"earned_tc" = earned_tc
			),
			"services" = list(
				"contracts" = contract_data,
				"events" = event_data,
				"market_items" = services.market_items,
				"agent_chat_messages" = chat_messages
			),
			"tabs" = list("services", "reinforcement", "black_market")
		)
		return payload

	proc/play_uplink_tab_animations()
		if(uplink_link)
			return uplink_link.play_tab_animations()
		return list()

/datum/traitor
	var/name = "Предатель"
	var/datum/traitor_reputation_system/reputation_system = null
	var/datum/uplink_controller/uplink_controller = null
	var/list/uplink_tabs = list()
	var/has_uplink = TRUE

	proc/Initialize(player_name = "Предатель")
		name = player_name ? ckey(player_name) : "Предатель"
		if(!name || name == "")
			name = "Предатель"
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
