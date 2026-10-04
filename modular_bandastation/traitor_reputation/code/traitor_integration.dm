/datum/antagonist/traitor
	var/datum/traitor_reputation_system/reputation_system
	var/passive_reputation_timer

/datum/antagonist/traitor/on_gain()
	. = ..()
	if(!reputation_system)
		reputation_system = new
		reputation_system.Initialize()
		if(owner)
			reputation_system.name = owner.name
	reputation_system.antagonist_owner = src
	reputation_system.uplink_handler = uplink_handler
	if(uplink_handler)
		uplink_handler.additional_purchase_check = CALLBACK(reputation_system, PROC_REF(can_purchase_uplink_item))
	reputation_system.schedule_random_activity()
	passive_reputation_timer = addtimer(CALLBACK(src, PROC_REF(passive_reputation_tick)), 1 MINUTES, TIMER_STOPPABLE)

/datum/antagonist/traitor/proc/passive_reputation_tick()
	if(!reputation_system)
		return
	reputation_system.add_reputation(reputation_system.passive_reputation_gain)
	passive_reputation_timer = addtimer(CALLBACK(src, PROC_REF(passive_reputation_tick)), 1 MINUTES, TIMER_STOPPABLE)

/datum/antagonist/traitor/on_removal()
	if(passive_reputation_timer)
		deltimer(passive_reputation_timer)
		passive_reputation_timer = null
	if(reputation_system)
		reputation_system.stop_random_activity()
		reputation_system.antagonist_owner = null
		if(uplink_handler)
			uplink_handler.additional_purchase_check = null
	return ..()

/datum/component/uplink/proc/handle_traitor_reputation_action(perk, mob/user, contract_id, message)
	var/datum/antagonist/traitor/traitor_datum = user.mind?.has_antag_datum(/datum/antagonist/traitor)
	if(!traitor_datum?.reputation_system)
		return
	var/datum/traitor_reputation_system/system = traitor_datum.reputation_system

	switch(perk)
		if("complete_item_contract")
			system.complete_item_contract(user, contract_id)
		if("agent_chat")
			if(!system.can_access_agent_chat())
				return
			if(!istext(message) || world.time < system.next_agent_chat_message)
				return
			var/clean_message = trim(sanitize(message), 200)
			if(!length_char(clean_message))
				return
			if(length(GLOB.traitor_agent_chat_messages))
				var/list/first_chat_message = GLOB.traitor_agent_chat_messages[1]
				if(first_chat_message["round_start_time"] != SSticker.round_start_time)
					GLOB.traitor_agent_chat_messages.Cut()
			GLOB.traitor_agent_chat_messages += list(list(
				"sender" = system.name,
				"message" = clean_message,
				"timestamp" = time2text(world.timeofday, "hh:mm"),
				"round_start_time" = SSticker.round_start_time,
			))
			system.next_agent_chat_message = world.time + 1 SECONDS
			if(length(GLOB.traitor_agent_chat_messages) > 100)
				GLOB.traitor_agent_chat_messages.Cut(1, 2)
			for(var/mob/living/player as anything in GLOB.player_list)
				var/datum/antagonist/traitor/recipient = player.mind?.has_antag_datum(/datum/antagonist/traitor)
				if(!recipient?.reputation_system?.can_access_agent_chat())
					continue
				var/datum/component/uplink/recipient_uplink = player.mind.find_syndicate_uplink()
				if(recipient_uplink)
					SStgui.update_uis(recipient_uplink)
		if("telecom_sabotage")
			if(!system.can_sabotage_telecomms())
				return
			var/datum/traitor_telecomms_sabotage/sabotage = new
			if(!sabotage.disable_network())
				qdel(sabotage)
				to_chat(user, span_warning("Не удалось вывести из строя телекоммуникационное оборудование."))
				return
			to_chat(user, span_notice("Телекоммуникационная сеть отключена на две минуты."))
		if("crew_conversion")
			if(!system.can_convert_crew())
				return
			var/list/eligible_targets = get_traitor_reputation_modpack()?.get_assassination_targets()
			if(!length(eligible_targets))
				to_chat(user, span_warning("Нет подходящих членов экипажа для вербовки."))
				return
			var/list/target_options = list()
			for(var/mob/living/target as anything in eligible_targets)
				target_options["[target.real_name] ([target.mind.assigned_role?.title || "экипаж"])"] = target
			var/mob/living/target = input(user, "Выберите члена экипажа для вербовки", "Вербовка Синдиката") as null|anything in target_options
			if(target)
				INVOKE_ASYNC(src, PROC_REF(offer_crew_conversion), target)
		if("kill_marker")
			if(!system.is_priority_target())
				return
			var/datum/modpack/traitor_reputation/modpack = get_traitor_reputation_modpack()
			var/list/eligible_targets = modpack?.get_assassination_targets()
			if(!length(eligible_targets))
				to_chat(user, span_warning("Нет подходящих целей для устранения."))
				return
			var/list/target_options = list()
			for(var/mob/living/target as anything in eligible_targets)
				target_options["[target.real_name] ([target.mind.assigned_role?.title || "экипаж"])"] = target
			var/mob/living/target = input(user, "Выберите приоритетную цель", "Маркер цели") as null|anything in target_options
			if(target)
				modpack.spawn_assassination_event(modpack.get_active_traitors(), target)
		if("evac_override")
			if(!system.is_priority_target())
				return
			var/obj/docking_port/mobile/emergency/shuttle = SSshuttle.emergency
			if(!shuttle || shuttle.mode != SHUTTLE_CALL)
				to_chat(user, span_warning("Сначала необходимо вызвать эвакуационный шаттл."))
				return
			shuttle.setTimer(min(shuttle.timeLeft(), 2 MINUTES))
			minor_announce("Обнаружено вмешательство в систему эвакуации. Отправление шаттла ускорено.", "СИСТЕМНОЕ ОПОВЕЩЕНИЕ")
			to_chat(user, span_notice("Отправление эвакуационного шаттла ускорено."))
		if("department_leak")
			if(!system.is_priority_target())
				return
			var/list/head_minds = SSjob.get_living_heads()
			if(!length(head_minds))
				to_chat(user, span_warning("Сейчас нет доступных глав отделов."))
				return
			to_chat(user, span_notice("Список глав отделов получен:"))
			for(var/datum/mind/head as anything in head_minds)
				to_chat(user, span_notice("- [head.name] ([head.assigned_role?.title || "неизвестно"])"))
		if("bureaucratic_interest")
			if(system.reputation < 600)
				return
			for(var/datum/mind/head as anything in SSjob.get_living_heads())
				if(head.current)
					to_chat(head.current, span_warning("В кадровых документах вашего отдела обнаружено несоответствие. Проверьте список сотрудников."))
			to_chat(user, span_notice("Руководителям отделов отправлено ложное уведомление о несоответствии в кадровых документах."))

/datum/component/uplink/proc/offer_crew_conversion(mob/living/target)
	if(QDELETED(target) || target.stat == DEAD || !target.mind || target.mind.has_antag_datum(/datum/antagonist/traitor))
		return
	to_chat(target, span_warning("В вашем аплинке появилось зашифрованное предложение от Синдиката."))
	if(tgui_alert(target, "Синдикат предлагает вам присоединиться к агентам. Принять предложение?", "Зашифрованное предложение", list("Принять", "Отказаться")) != "Принять")
		return
	target.mind.add_antag_datum(/datum/antagonist/traitor)
	to_chat(target, span_notice("Вербовка завершена. Загляните в аплинк, чтобы узнать дальнейшие инструкции."))

/datum/component/uplink/proc/get_traitor_reputation_modpack()
	return get_loaded_traitor_reputation_modpack()

/datum/traitor_telecomms_sabotage
	var/list/machine_states = list()

/datum/traitor_telecomms_sabotage/proc/disable_network()
	for(var/obj/machinery/telecomms/machine as anything in GLOB.telecomm_machines)
		if(machine.toggled)
			machine_states[machine] = TRUE
			machine.toggled = FALSE
			machine.update_power()
	if(!length(machine_states))
		return FALSE
	addtimer(CALLBACK(src, PROC_REF(restore_network)), 2 MINUTES, TIMER_DELETE_ME)
	return TRUE

/datum/traitor_telecomms_sabotage/proc/restore_network()
	for(var/obj/machinery/telecomms/machine as anything in machine_states)
		if(!QDELETED(machine))
			machine.toggled = machine_states[machine]
			machine.update_power()
