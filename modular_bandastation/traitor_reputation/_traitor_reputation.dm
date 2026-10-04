/datum/modpack/traitor_reputation
	name = "Реворк Трейтор Репутации"
	desc = "Изменяет систему репутации трейтора, чтобы сделать её более справедливой и интересной."
	author = "rambutan1337"

/datum/modpack/traitor_reputation
	var/next_cargo_event = 0
	var/next_assassination_event = 0
	var/list/completed_cargo_events = list()
	var/list/cargo_crystal_events = list()

/datum/modpack/traitor_reputation/post_initialize()
	addtimer(CALLBACK(src, PROC_REF(check_automatic_events)), 1 MINUTES, TIMER_STOPPABLE)

/datum/modpack/traitor_reputation/proc/get_active_traitors()
	var/list/traitors = list()
	for(var/mob/living/player as anything in GLOB.player_list)
		if(!player.mind)
			continue
		var/datum/antagonist/traitor/traitor_datum = player.mind.has_antag_datum(/datum/antagonist/traitor)
		if(traitor_datum?.reputation_system)
			traitors |= traitor_datum
	return traitors

/datum/modpack/traitor_reputation/proc/get_assassination_targets()
	var/list/targets = list()
	for(var/mob/living/player as anything in GLOB.player_list)
		if(!player.mind || player.stat == DEAD)
			continue
		if(length(player.mind.antag_datums))
			continue
		targets |= player
	return targets

/proc/get_loaded_traitor_reputation_modpack()
	for(var/datum/modpack/modpack as anything in SSmodpacks.loaded_modpacks)
		if(istype(modpack, /datum/modpack/traitor_reputation))
			return modpack
	return null

/datum/modpack/traitor_reputation/proc/check_automatic_events()
	var/list/traitors = get_active_traitors()
	var/traitor_count = length(traitors)
	if(traitor_count >= 3 && traitor_count <= 4 && world.time >= next_cargo_event)
		if(spawn_cargo_event(traitors))
			next_cargo_event = world.time + 20 MINUTES
	if(traitor_count >= 4 && traitor_count <= 5 && world.time >= next_assassination_event)
		if(spawn_assassination_event(traitors))
			next_assassination_event = world.time + 20 MINUTES
	addtimer(CALLBACK(src, PROC_REF(check_automatic_events)), 1 MINUTES, TIMER_STOPPABLE)

/datum/modpack/traitor_reputation/proc/spawn_cargo_event(list/traitors)
	if(!length(traitors))
		return FALSE

	var/list/station_departments = list(
		list("area" = /area/station/engineering, "name" = "Инженерный отдел"),
		list("area" = /area/station/medical, "name" = "Медицинский отдел"),
		list("area" = /area/station/science, "name" = "Научный отдел"),
		list("area" = /area/station/security, "name" = "Служба безопасности"),
		list("area" = /area/station/cargo, "name" = "Карго"),
	)
	var/list/valid_departments = list()
	for(var/list/department as anything in station_departments)
		var/list/department_areas = get_areas(department["area"])
		if(length(department_areas) && length(get_area_turfs(pick(department_areas), subtypes = TRUE)))
			valid_departments += list(department)
	if(!length(valid_departments))
		return FALSE

	var/list/selected_department = pick(valid_departments)
	var/event_id = REF(src) + "-[world.time]-[rand(1, 1000000)]"
	var/obj/structure/closet/crate/cargo_drop = new
	cargo_drop.name = "неопознанный груз Синдиката"
	cargo_drop.desc = "Запечатанный грузовой контейнер с подозрительно хорошо охраняемым содержимым."
	var/obj/item/stack/telecrystal/cargo_crystal = new(cargo_drop)
	var/obj/item/paper/manifest = new(cargo_drop)
	manifest.name = "зашифрованная грузовая накладная"
	manifest.add_raw_text("Перехваченная поставка. Найдите контейнер в указанном отделе и заберите кристалл.")

	if(!send_supply_pod_to_area(list(cargo_drop), selected_department["area"]))
		qdel(cargo_drop)
		return FALSE
	cargo_crystal_events[cargo_crystal] = event_id
	RegisterSignal(cargo_crystal, COMSIG_ITEM_PICKUP, TYPE_PROC_REF(/datum/modpack/traitor_reputation, on_cargo_crystal_pickup))

	for(var/datum/antagonist/traitor/traitor_datum as anything in traitors)
		traitor_datum.reputation_system.create_agent_event(
			"very_important_cargo",
			"Найдите неопознанный контейнер и заберите кристалл. Место доставки: [selected_department["name"]].",
			selected_department["name"],
			event_id,
			5,
			20,
			100,
		)
	priority_announce("Обнаружен незарегистрированный грузовой контейнер в районе «[selected_department["name"]]».", "Служба снабжения")
	return TRUE

/datum/modpack/traitor_reputation/proc/on_cargo_crystal_pickup(obj/item/stack/telecrystal/source, mob/living/picker)
	SIGNAL_HANDLER
	var/event_id = cargo_crystal_events[source]
	if(!event_id)
		return
	if(!picker?.mind?.has_antag_datum(/datum/antagonist/traitor) || event_id in completed_cargo_events)
		return
	var/datum/antagonist/traitor/traitor_datum = picker.mind.has_antag_datum(/datum/antagonist/traitor)
	var/datum/traitor_reputation_system/system = traitor_datum?.reputation_system
	if(!system)
		return
	var/datum/traitor_event/cargo_event
	for(var/datum/traitor_event/event as anything in system.active_events)
		if(event.event_id == event_id && event.event_name == "very_important_cargo")
			cargo_event = event
			break
	if(!cargo_event)
		return

	completed_cargo_events |= event_id
	cargo_crystal_events -= source
	var/list/result = system.apply_event_reward("very_important_cargo", TRUE)
	var/list/active_traitors = get_active_traitors()
	for(var/datum/antagonist/traitor/active_traitor as anything in active_traitors)
		var/datum/traitor_reputation_system/active_system = active_traitor.reputation_system
		for(var/datum/traitor_event/event as anything in active_system.active_events.Copy())
			if(event.event_id == event_id)
				active_system.remove_event(event)
	to_chat(picker, span_notice("Груз забран. Награда: [result["rep_gained"]] REP и [result["tc_gained"]] TC."))
	qdel(source)

/datum/modpack/traitor_reputation/proc/spawn_assassination_event(list/traitors, mob/living/target)
	if(!length(traitors))
		return FALSE
	if(!target)
		var/list/eligible_targets = get_assassination_targets()
		if(!length(eligible_targets))
			return FALSE
		target = pick(eligible_targets)
	if(!target.mind || target.stat == DEAD)
		return FALSE
	var/datum/record/crew/manifest_record = get_manifest_record(target)
	if(!manifest_record)
		return FALSE

	for(var/datum/antagonist/traitor/traitor_datum as anything in traitors)
		var/datum/traitor_reputation_system/system = traitor_datum.reputation_system
		for(var/datum/traitor_contract/existing_contract as anything in system.active_contracts)
			if(existing_contract.contract_type == "assassination" && existing_contract.required_target == manifest_record.name && !existing_contract.accepted)
				return FALSE
	for(var/datum/antagonist/traitor/traitor_datum as anything in traitors)
		var/datum/traitor_reputation_system/system = traitor_datum.reputation_system
		var/datum/traitor_contract/contract = system.generate_contract(
			"assassination",
			manifest_record.rank,
			manifest_record.name,
		)
		contract.required_role = manifest_record.rank
		contract.reward_tc = 5
		contract.tc_drop_chance = rand(30, 45)
		contract.reputation_reward = 20
		contract.description = "Устраните цель: [manifest_record.name], [manifest_record.rank]. За ликвидацию начисляется 20 REP; 5 TC выпадают с шансом [contract.tc_drop_chance]%."
		new /datum/traitor_assassination_tracker(target, system, contract, FALSE)
		system.create_agent_event(
			"kill_but_not_finished",
			"Получено досье на цель: [manifest_record.name], [manifest_record.rank]. Устраните её для получения награды.",
			manifest_record.rank,
			"",
			contract.reward_tc,
			contract.reputation_reward,
			contract.tc_drop_chance,
		)
	return TRUE

/datum/modpack/traitor_reputation/proc/get_manifest_record(mob/living/target)
	if(!target)
		return null
	for(var/datum/record/crew/crew_record as anything in GLOB.manifest.general)
		if(crew_record.name == target.real_name)
			return crew_record
	return null

/datum/modpack/traitor_reputation/proc/create_hitman_contracts(list/traitors, mob/living/target)
	if(!length(traitors) || !target || target.stat == DEAD)
		return FALSE
	var/datum/record/crew/manifest_record = get_manifest_record(target)
	if(!manifest_record)
		return FALSE

	for(var/datum/antagonist/traitor/traitor_datum as anything in traitors)
		var/datum/traitor_reputation_system/system = traitor_datum.reputation_system
		var/datum/traitor_contract/contract
		for(var/datum/traitor_contract/existing_contract as anything in system.active_contracts)
			if(existing_contract.contract_type == "assassination" && existing_contract.required_target == manifest_record.name && !existing_contract.accepted)
				contract = existing_contract
				break
		if(contract)
			contract.reward_tc = 10
			contract.required_role = manifest_record.rank
			contract.description = "Устраните цель: [manifest_record.name], [manifest_record.rank]. Награда: 10 TC."
			system.uplink_handler?.on_update()
			continue

		contract = system.generate_contract("assassination", manifest_record.rank, manifest_record.name)
		contract.required_role = manifest_record.rank
		contract.description = "Устраните цель: [manifest_record.name], [manifest_record.rank]. Награда: 10 TC."
		contract.reward_tc = 10
		contract.reputation_reward = 100
		new /datum/traitor_assassination_tracker(target, system, contract, TRUE)
		system.create_agent_event(
			"hitman_contract",
			"Цель для устранения: [manifest_record.name], [manifest_record.rank]. Награда: 10 TC.",
			manifest_record.rank,
			"",
			10,
			100,
			100,
		)
	return TRUE

/datum/traitor_assassination_tracker
	var/datum/weakref/target_ref
	var/datum/traitor_reputation_system/system
	var/datum/traitor_contract/contract
	var/datum/weakref/last_attacker_ref
	var/last_attack_time = 0
	var/was_smitten = FALSE

/datum/traitor_assassination_tracker/New(mob/living/target, datum/traitor_reputation_system/system_input, datum/traitor_contract/contract_input, smited = FALSE)
	. = ..()
	target_ref = WEAKREF(target)
	system = system_input
	contract = contract_input
	was_smitten = smited
	RegisterSignal(target, COMSIG_LIVING_DEATH, PROC_REF(on_target_death))
	RegisterSignal(target, COMSIG_QDELETING, PROC_REF(on_target_deleting))
	RegisterSignal(target, "traitor_reputation_smite", PROC_REF(on_target_smite))
	RegisterSignals(target, list(
		COMSIG_ATOM_AFTER_ATTACKEDBY,
	), PROC_REF(on_target_attacked_by_item))
	RegisterSignal(target, COMSIG_ATOM_BULLET_ACT, PROC_REF(on_target_bullet_hit))
	RegisterSignals(target, list(
		COMSIG_ATOM_ATTACK_HAND,
		COMSIG_ATOM_ATTACK_PAW,
		COMSIG_ATOM_ATTACK_ROBOT,
	), PROC_REF(on_target_attacked_by_mob))
	RegisterSignal(target, COMSIG_ATOM_ATTACK_MECH, PROC_REF(on_target_attacked_by_mech))

/datum/traitor_assassination_tracker/Destroy()
	var/mob/living/target = target_ref?.resolve()
	if(target)
		UnregisterSignal(target, COMSIG_LIVING_DEATH)
		UnregisterSignal(target, COMSIG_QDELETING)
		UnregisterSignal(target, "traitor_reputation_smite")
		UnregisterSignal(target, list(
			COMSIG_ATOM_AFTER_ATTACKEDBY,
			COMSIG_ATOM_ATTACK_HAND,
			COMSIG_ATOM_ATTACK_PAW,
			COMSIG_ATOM_ATTACK_ROBOT,
		))
		UnregisterSignal(target, COMSIG_ATOM_BULLET_ACT)
		UnregisterSignal(target, COMSIG_ATOM_ATTACK_MECH)
	target_ref = null
	last_attacker_ref = null
	system = null
	contract = null
	return ..()

/datum/traitor_assassination_tracker/proc/on_target_death(datum/source, gibbed)
	SIGNAL_HANDLER
	var/mob/living/last_attacker = last_attacker_ref?.resolve()
	var/traitor_kill = last_attacker && last_attacker.mind?.has_antag_datum(/datum/antagonist/traitor)
	var/recent_traitor_kill = traitor_kill && world.time - last_attack_time <= 30 SECONDS
	if(system && (was_smitten || recent_traitor_kill))
		system.complete_assassination(contract, was_smitten)
	qdel(src)

/datum/traitor_assassination_tracker/proc/on_target_deleting(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/datum/traitor_assassination_tracker/proc/on_target_smite(datum/source)
	SIGNAL_HANDLER
	was_smitten = TRUE

/datum/traitor_assassination_tracker/proc/on_target_attacked_by_item(datum/source, obj/item/weapon, mob/living/attacker, list/modifiers)
	SIGNAL_HANDLER
	record_attacker(attacker)

/datum/traitor_assassination_tracker/proc/on_target_bullet_hit(datum/source, obj/projectile/projectile, def_zone, piercing_hit, blocked)
	SIGNAL_HANDLER
	record_attacker(projectile.firer)

/datum/traitor_assassination_tracker/proc/on_target_attacked_by_mob(datum/source, mob/living/attacker, list/modifiers)
	SIGNAL_HANDLER
	record_attacker(attacker)

/datum/traitor_assassination_tracker/proc/on_target_attacked_by_mech(datum/source, obj/vehicle/sealed/mecha/mecha, mob/living/attacker)
	SIGNAL_HANDLER
	record_attacker(attacker || mecha.occupants[1])

/datum/traitor_assassination_tracker/proc/record_attacker(mob/living/attacker)
	last_attacker_ref = attacker?.mind?.has_antag_datum(/datum/antagonist/traitor) ? WEAKREF(attacker) : null
	last_attack_time = world.time

/datum/smite/do_effect(client/user, mob/living/target)
	SEND_SIGNAL(target, "traitor_reputation_smite")
	return ..()

/datum/smite/get_a_hitman
	name = "Get a Hitman"

/datum/smite/get_a_hitman/effect(client/user, mob/living/target)
	. = ..()
	var/datum/modpack/traitor_reputation/reputation_modpack = get_loaded_traitor_reputation_modpack()
	if(!reputation_modpack)
		to_chat(user, span_warning("Модпак репутации предателя не загружен. Контракт не создан."))
		return
	var/list/traitors = reputation_modpack.get_active_traitors()
	if(!length(traitors))
		to_chat(user, span_warning("Нет активных предателей с аплинком репутации. Контракт не создан."))
		return
	if(!reputation_modpack.create_hitman_contracts(traitors, target))
		to_chat(user, span_warning("Цель не найдена в манифесте экипажа. Контракт не создан."))
		return
	to_chat(user, span_notice("Контракт на устранение [target.real_name] ([reputation_modpack.get_manifest_record(target).rank]) добавлен в аплинки предателей."))

ADMIN_VERB(spawn_traitor_reputation_event, R_ADMIN, "Запустить событие репутации предателей", "Создать грузовое событие или контракт на устранение для активных предателей.", ADMIN_CATEGORY_EVENTS)
	var/datum/modpack/traitor_reputation/reputation_modpack = get_loaded_traitor_reputation_modpack()
	if(!reputation_modpack)
		to_chat(user, span_warning("Модпак репутации предателя не загружен."))
		return
	var/event_type = input(user.mob, "Выберите событие для запуска", "Репутация предателя") as null|anything in list("Грузовой контейнер", "Контракт на устранение")
	if(!event_type)
		return
	var/list/traitors = reputation_modpack.get_active_traitors()
	if(!length(traitors))
		to_chat(user, span_warning("Нет активных предателей с аплинком репутации."))
		return
	if(event_type == "Грузовой контейнер")
		if(!reputation_modpack.spawn_cargo_event(traitors))
			to_chat(user, span_warning("Не удалось найти подходящую площадку для доставки груза."))
			return
	else
		var/list/targets = reputation_modpack.get_assassination_targets()
		if(!length(targets))
			to_chat(user, span_warning("Нет подходящих целей для контракта на устранение."))
			return
		var/list/target_options = list()
		for(var/mob/living/target as anything in targets)
			target_options["[target.real_name] ([target.mind.assigned_role?.title || "экипаж"])"] = target
		var/mob/living/selected_target = input(user.mob, "Выберите цель для устранения", "Репутация предателя") as null|anything in target_options
		if(!selected_target)
			return
		if(!reputation_modpack.spawn_assassination_event(traitors, selected_target))
			to_chat(user, span_warning("Не удалось создать контракт на устранение."))
			return
	log_admin("[key_name(user)] запустил событие «[event_type]» для [length(traitors)] предателей.")
	message_admins("[key_name_admin(user)] запустил событие «[event_type]» для [length(traitors)] предателей.")
