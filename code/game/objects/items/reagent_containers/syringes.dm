////////////////////////////////////////////////////////////////////////////////
/// Syringes.
////////////////////////////////////////////////////////////////////////////////
#define SYRINGE_DRAW 0
#define SYRINGE_INJECT 1
#define SYRINGE_BROKEN 2

/obj/item/reagent_container/syringe
	name = "syringe"
	desc = "A syringe."
	icon = 'icons/obj/items/syringe.dmi'
	item_state = "syringe_0"
	icon_state = "0"
	matter = list("glass" = 150)
	amount_per_transfer_from_this = 5
	possible_transfer_amounts = null //list(5,10,15)
	volume = 15
	w_class = 1
	flags_item = NOBLUDGEON
	sharp = IS_SHARP_ITEM_SIMPLE
	var/mode = SYRINGE_DRAW

/obj/item/reagent_container/syringe/on_reagent_change()
	update_icon()

/obj/item/reagent_container/syringe/pickup(mob/user)
	..()
	update_icon()

/obj/item/reagent_container/syringe/dropped(mob/user)
	..()
	update_icon()



/obj/item/reagent_container/syringe/examine(mob/user)
	..()
	display_contents(user)


/obj/item/reagent_container/syringe/attack_self(mob/user as mob)

	switch(mode)
		if(SYRINGE_DRAW)
			mode = SYRINGE_INJECT
		if(SYRINGE_INJECT)
			mode = SYRINGE_DRAW
		if(SYRINGE_BROKEN)
			return
	update_icon()

/obj/item/reagent_container/syringe/attack_hand()
	..()
	update_icon()

/obj/item/reagent_container/syringe/attack_paw()
	return attack_hand()

/obj/item/reagent_container/syringe/attackby(obj/item/I as obj, mob/user as mob)
	return

/obj/item/reagent_container/syringe/afterattack(obj/target, mob/user, proximity)
	if(!proximity) return
	if(!target.reagents) return

	if(mode == SYRINGE_BROKEN)
		user << "\red This syringe is broken!"
		return

	if (user.a_intent == "hurt" && ismob(target))
		if((CLUMSY in user.mutations) && prob(50))
			target = user
		var/mob/M = target
		if(M != user && M.stat != DEAD && M.a_intent != "help" && !M.is_mob_incapacitated() && ((M.mind && M.mind.cm_skills && M.mind.cm_skills.cqc >= SKILL_CQC_MP) || isYautja(M))) // preds have null skills
			user.KnockDown(3)
			M.attack_log += text("\[[time_stamp()]\] <font color='orange'>Used cqc skill to stop [user.name] ([user.ckey]) injecting them.</font>")
			user.attack_log += text("\[[time_stamp()]\] <font color='red'>Was stopped from injecting [M] ([M.ckey]) by their cqc skill.</font>")
			msg_admin_attack("[user.name] ([user.ckey]) got robusted by the cqc of [M.name] ([M.key]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")
			M.visible_message("<span class='danger'>[M]'s reflexes kick in and knock [user] to the ground before they could use \the [src]'!</span>", \
				"<span class='warning'>You knock [user] to the ground before they inject you!</span>", null, 5)
			playsound(user.loc, 'sound/weapons/thudswoosh.ogg', 25, 1, 7)
			return

		syringestab(target, user)
		return

	var/injection_time = 30
	if(user.mind && user.mind.cm_skills)
		if(user.mind.cm_skills.medical < SKILL_MEDICAL_MEDIC)
			user << "<span class='warning'>You aren't trained to use syringes...</span>"
			return
		else
			injection_time = max(5, 50 - 10*user.mind.cm_skills.medical)


	switch(mode)
		if(SYRINGE_DRAW)

			if(reagents.total_volume >= reagents.maximum_volume)
				user << "\red The syringe is full."
				return

			if(ismob(target))//Blood!
				if(iscarbon(target))//maybe just add a blood reagent to all mobs. Then you can suck them dry...With hundreds of syringes. Jolly good idea.
					var/amount = src.reagents.maximum_volume - src.reagents.total_volume
					var/mob/living/carbon/T = target
					if(T.get_blood_id() && reagents.has_reagent(T.get_blood_id()))
						user << "\red There is already a blood sample in this syringe"
						return
					if(!T.dna)
						user << "You are unable to locate any blood."
						return
					if(NOCLONE in T.mutations) //target done been et, no more blood in him
						user << "\red You are unable to locate any blood."
						return

					if(ishuman(T))
						var/mob/living/carbon/human/H = T
						if(H.species.flags & NO_BLOOD)
							user << "\red You are unable to locate any blood."
							return
						else
							T.take_blood(src,amount)
					else
						T.take_blood(src,amount)

					on_reagent_change()
					reagents.handle_reactions()
					user.visible_message("<span clas='warning'>[user] takes a blood sample from [target].</span>",
										"<span class='notice'>You take a blood sample from [target].</span>", null, 4)

			else //if not mob
				if(!target.reagents.total_volume)
					user << "\red [target] is empty."
					return

				if(!target.is_open_container() && !istype(target,/obj/structure/reagent_dispensers))
					user << "\red You cannot directly remove reagents from this object."
					return

				var/trans = target.reagents.trans_to(src, amount_per_transfer_from_this) // transfer from, transfer to - who cares?

				user << "\blue You fill the syringe with [trans] units of the solution."
			if (reagents.total_volume >= reagents.maximum_volume)
				mode=!mode
				update_icon()

		if(SYRINGE_INJECT)
			if(!reagents.total_volume)
				user << "\red The syringe is empty."
				return
			if(istype(target, /obj/item/implantcase/chem))
				return

			if(!target.is_open_container() && !ismob(target) && !istype(target, /obj/item/reagent_container/food) && !istype(target, /obj/item/clothing/mask/cigarette) && !istype(target, /obj/item/storage/fancy/cigarettes))
				user << "\red You cannot directly fill this object."
				return
			if(target.reagents.total_volume >= target.reagents.maximum_volume)
				user << "\red [target] is full."
				return

			if(ismob(target))
				if(target != user)

					if(ishuman(target))

						var/mob/living/carbon/human/H = target
						if(H.wear_suit)
							if(istype(H.wear_suit,/obj/item/clothing/suit/space))
								injection_time = 60
							else if(!H.can_inject(user, 1))
								return

					else if(isliving(target))

						var/mob/living/M = target
						if(!M.can_inject(user, 1))
							return

					if(injection_time != 60)
						user.visible_message("\red <B>[user] is trying to inject [target]!</B>")
					else
						user.visible_message("\red <B>[user] begins hunting for an injection port on [target]'s suit!</B>")

					if(!do_mob(user, target, injection_time, BUSY_ICON_FRIENDLY, BUSY_ICON_MEDICAL)) return

					user.visible_message("\red [user] injects [target] with the syringe!")

					if(istype(target,/mob/living))
						var/mob/living/M = target
						var/list/injected = list()
						for(var/datum/reagent/R in src.reagents.reagent_list)
							injected += R.name
						var/contained = english_list(injected)
						M.attack_log += text("\[[time_stamp()]\] <font color='orange'>Has been injected with [src.name] by [user.name] ([user.ckey]). Reagents: [contained]</font>")
						user.attack_log += text("\[[time_stamp()]\] <font color='red'>Used the [src.name] to inject [M.name] ([M.key]). Reagents: [contained]</font>")
						msg_admin_attack("[user.name] ([user.ckey]) injected [M.name] ([M.key]) with [src.name]. Reagents: [contained] (INTENT: [uppertext(user.a_intent)]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")

				reagents.reaction(target, INGEST)


			var/trans = amount_per_transfer_from_this
			if(iscarbon(target) && locate(/datum/reagent/blood) in reagents.reagent_list)
				var/mob/living/carbon/C = target
				C.inject_blood(src, amount_per_transfer_from_this)
			else
				trans = reagents.trans_to(target, amount_per_transfer_from_this)

			user << "\blue You inject [trans] units of the solution. The syringe now contains [src.reagents.total_volume] units."
			if (reagents.total_volume <= 0 && mode==SYRINGE_INJECT)
				mode = SYRINGE_DRAW
				update_icon()


/obj/item/reagent_container/syringe/update_icon()
	if(mode == SYRINGE_BROKEN)
		icon_state = "broken"
		overlays.Cut()
		return
	var/rounded_vol = round(reagents.total_volume,5)
	overlays.Cut()
	if(ismob(loc))
		var/injoverlay
		switch(mode)
			if (SYRINGE_DRAW)
				injoverlay = "draw"
			if (SYRINGE_INJECT)
				injoverlay = "inject"
		overlays += injoverlay
	icon_state = "[rounded_vol]"
	item_state = "syringe_[rounded_vol]"

	if(reagents.total_volume)
		var/image/filling = image('icons/obj/reagentfillings.dmi', src, "syringe10")

		filling.icon_state = "syringe[rounded_vol]"

		filling.color = mix_color_from_reagents(reagents.reagent_list)
		overlays += filling


/obj/item/reagent_container/syringe/proc/syringestab(mob/living/carbon/target as mob, mob/living/carbon/user as mob)

	user.attack_log += "\[[time_stamp()]\]<font color='red'> Attacked [target.name] ([target.ckey]) with [src.name] (INTENT: [uppertext(user.a_intent)])</font>"
	target.attack_log += "\[[time_stamp()]\]<font color='orange'> Attacked by [user.name] ([user.ckey]) with [src.name] (INTENT: [uppertext(user.a_intent)])</font>"
	msg_admin_attack("[user.name] ([user.ckey]) attacked [target.name] ([target.ckey]) with [src.name] (INTENT: [uppertext(user.a_intent)]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")

	if(istype(target, /mob/living/carbon/human))

		var/target_zone = ran_zone(check_zone(user.zone_selected, target))
		var/datum/limb/affecting = target:get_limb(target_zone)

		if (!affecting)
			return
		if(affecting.status & LIMB_DESTROYED)
			user << "What [affecting.display_name]?"
			return
		var/hit_area = affecting.display_name

		var/mob/living/carbon/human/H = target
		if((user != target) && H.check_shields(7, "the [src.name]"))
			return

		if (target != user && target.getarmor(target_zone, "melee") > 5 && prob(50))
			for(var/mob/O in viewers(world.view, user))
				O.show_message(text("\red <B>[user] tries to stab [target] in \the [hit_area] with [src.name], but the attack is deflected by armor!</B>"), 1)
			user.temp_drop_inv_item(src)
			cdel(src)
			return

		for(var/mob/O in viewers(world.view, user))
			O.show_message(text("\red <B>[user] stabs [target] in \the [hit_area] with [src.name]!</B>"), 1)

		if(affecting.take_damage(3))
			target:UpdateDamageIcon()

	else
		for(var/mob/O in viewers(world.view, user))
			O.show_message(text("\red <B>[user] stabs [target] with [src.name]!</B>"), 1)
		target.take_limb_damage(3)// 7 is the same as crowbar punch

	src.reagents.reaction(target, INGEST)
	var/syringestab_amount_transferred = rand(0, (reagents.total_volume - 5)) //nerfed by popular demand
	src.reagents.trans_to(target, syringestab_amount_transferred)
	src.desc += " It is broken."
	src.mode = SYRINGE_BROKEN
	src.add_mob_blood(target)
	src.add_fingerprint(usr)
	src.update_icon()


/obj/item/reagent_container/ld50_syringe
	name = "Lethal Injection Syringe"
	desc = "A syringe used for lethal injections."
	icon = 'icons/obj/items/syringe.dmi'
	item_state = "syringe_0"
	icon_state = "0"
	amount_per_transfer_from_this = 50
	possible_transfer_amounts = null //list(5,10,15)
	volume = 50
	var/mode = SYRINGE_DRAW

	on_reagent_change()
		update_icon()

	pickup(mob/user)
		..()
		update_icon()

	dropped(mob/user)
		..()
		update_icon()

	attack_self(mob/user as mob)
		mode = !mode
		update_icon()

	attack_hand()
		..()
		update_icon()

	attack_paw()
		return attack_hand()

	attackby(obj/item/I as obj, mob/user as mob)

		return

	afterattack(obj/target, mob/user , flag)
		if(!target.reagents) return

		switch(mode)
			if(SYRINGE_DRAW)

				if(reagents.total_volume >= reagents.maximum_volume)
					user << "\red The syringe is full."
					return

				if(ismob(target))
					if(istype(target, /mob/living/carbon))//I Do not want it to suck 50 units out of people
						usr << "This needle isn't designed for drawing blood."
						return
				else //if not mob
					if(!target.reagents.total_volume)
						user << "\red [target] is empty."
						return

					if(!target.is_open_container() && !istype(target,/obj/structure/reagent_dispensers))
						user << "\red You cannot directly remove reagents from this object."
						return

					var/trans = target.reagents.trans_to(src, amount_per_transfer_from_this) // transfer from, transfer to - who cares?

					user << "\blue You fill the syringe with [trans] units of the solution."
				if (reagents.total_volume >= reagents.maximum_volume)
					mode=!mode
					update_icon()

			if(SYRINGE_INJECT)
				if(!reagents.total_volume)
					user << "\red The Syringe is empty."
					return
				if(istype(target, /obj/item/implantcase/chem))
					return
				if(!target.is_open_container() && !ismob(target) && !istype(target, /obj/item/reagent_container/food))
					user << "\red You cannot directly fill this object."
					return
				if(target.reagents.total_volume >= target.reagents.maximum_volume)
					user << "\red [target] is full."
					return

				if(ismob(target) && target != user)
					user.visible_message("\red <B>[user] is trying to inject [target] with a giant syringe!</B>")
					if(!do_mob(user, target, 300, BUSY_ICON_FRIENDLY, BUSY_ICON_MEDICAL)) return
					user.visible_message("\red [user] injects [target] with a giant syringe!")
					src.reagents.reaction(target, INGEST)
				if(ismob(target) && target == user)
					src.reagents.reaction(target, INGEST)
				spawn(5)
					var/trans = src.reagents.trans_to(target, amount_per_transfer_from_this)
					user << "\blue You inject [trans] units of the solution. The syringe now contains [src.reagents.total_volume] units."
					if (reagents.total_volume >= reagents.maximum_volume && mode==SYRINGE_INJECT)
						mode = SYRINGE_DRAW
						update_icon()
		return


	update_icon()
		var/rounded_vol = round(reagents.total_volume,50)
		if(ismob(loc))
			var/mode_t
			switch(mode)
				if (SYRINGE_DRAW)
					mode_t = "d"
				if (SYRINGE_INJECT)
					mode_t = "i"
			icon_state = "[mode_t][rounded_vol]"
		else
			icon_state = "[rounded_vol]"
		item_state = "syringe_[rounded_vol]"


////////////////////////////////////////////////////////////////////////////////
/// Syringes. END
////////////////////////////////////////////////////////////////////////////////



/obj/item/reagent_container/syringe/inaprovaline
	name = "syringe (Inaprovaline)"
	desc = "Contains inaprovaline - used to stabilize patients."
	New()
		..()
		reagents.add_reagent("inaprovaline", 15)
		mode = SYRINGE_INJECT
		update_icon()

/obj/item/reagent_container/syringe/antitoxin
	name = "syringe (anti-toxin)"
	desc = "Contains anti-toxins."
	New()
		..()
		reagents.add_reagent("anti_toxin", 15)
		mode = SYRINGE_INJECT
		update_icon()

/obj/item/reagent_container/syringe/antiviral
	name = "syringe (Spaceacillin)"
	desc = "Contains antiviral agents. Can also be used to treat infected wounds."
	New()
		..()
		reagents.add_reagent("spaceacillin", 15)
		mode = SYRINGE_INJECT
		update_icon()

/obj/item/reagent_container/syringe/drugs
	name = "syringe (drugs)"
	desc = "Contains aggressive drugs meant for torture."
	New()
		..()
		reagents.add_reagent("space_drugs",  5)
		reagents.add_reagent("mindbreaker",  5)
		reagents.add_reagent("cryptobiolin", 5)
		mode = SYRINGE_INJECT
		update_icon()

/obj/item/reagent_container/ld50_syringe/choral
	New()
		..()
		reagents.add_reagent("chloralhydrate", 50)
		mode = SYRINGE_INJECT
		update_icon()


//Robot syringes
//Not special in any way, code wise. They don't have added variables or procs.
/obj/item/reagent_container/syringe/robot/antitoxin
	name = "syringe (anti-toxin)"
	desc = "Contains anti-toxins."
	New()
		..()
		reagents.add_reagent("anti_toxin", 15)
		mode = SYRINGE_INJECT
		update_icon()

/obj/item/reagent_container/syringe/robot/inoprovaline
	name = "syringe (Inoprovaline)"
	desc = "Contains inaprovaline - used to stabilize patients."
	New()
		..()
		reagents.add_reagent("inaprovaline", 15)
		mode = SYRINGE_INJECT
		update_icon()

/obj/item/reagent_container/syringe/robot/mixed
	name = "syringe (mixed)"
	desc = "Contains inaprovaline & anti-toxins."
	New()
		..()
		reagents.add_reagent("inaprovaline", 7)
		reagents.add_reagent("anti_toxin", 8)
		mode = SYRINGE_INJECT
		update_icon()