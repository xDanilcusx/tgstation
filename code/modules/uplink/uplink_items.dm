GLOBAL_LIST_INIT(uplink_items, subtypesof(/datum/uplink_item))

/proc/get_uplink_items(datum/game_mode/gamemode = null, allow_sales = TRUE, allow_restricted = TRUE)
	var/list/filtered_uplink_items = list()
	var/list/sale_items = list()

	for(var/path in GLOB.uplink_items)
		var/datum/uplink_item/I = new path
		if(!I.item)
			continue
		if(I.include_modes.len)
			if(!gamemode && SSticker.mode && !(SSticker.mode.type in I.include_modes))
				continue
			if(gamemode && !(gamemode in I.include_modes))
				continue
		if(I.exclude_modes.len)
			if(!gamemode && SSticker.mode && (SSticker.mode.type in I.exclude_modes))
				continue
			if(gamemode && (gamemode in I.exclude_modes))
				continue
		if(I.player_minimum && I.player_minimum > GLOB.joined_player_list.len)
			continue
		if (I.restricted && !allow_restricted)
			continue

		if(!filtered_uplink_items[I.category])
			filtered_uplink_items[I.category] = list()
		filtered_uplink_items[I.category][I.name] = I
		if(I.limited_stock < 0 && !I.cant_discount && I.item && I.cost > 1)
			sale_items += I
	if(allow_sales)
		var/datum/team/nuclear/nuclear_team
		if (gamemode == /datum/game_mode/nuclear) 					// uplink code kind of needs a redesign
			nuclear_team = locate() in GLOB.antagonist_teams	// the team discounts could be in a GLOB with this design but it would make sense for them to be team specific...
		if (!nuclear_team)
			create_uplink_sales(3, "Discounted Gear", 1, sale_items, filtered_uplink_items)
		else
			if (!nuclear_team.team_discounts)
				// create 5 unlimited stock discounts
				create_uplink_sales(5, "Discounted Team Gear", -1, sale_items, filtered_uplink_items)
				// Create 10 limited stock discounts
				create_uplink_sales(10, "Limited Stock Team Gear", 1, sale_items, filtered_uplink_items)
				nuclear_team.team_discounts = list("Discounted Team Gear" = filtered_uplink_items["Discounted Team Gear"], "Limited Stock Team Gear" = filtered_uplink_items["Limited Stock Team Gear"])
			else
				for(var/cat in nuclear_team.team_discounts)
					for(var/item in nuclear_team.team_discounts[cat])
						var/datum/uplink_item/D = nuclear_team.team_discounts[cat][item]
						var/datum/uplink_item/O = filtered_uplink_items[initial(D.category)][initial(D.name)]
						O.refundable = FALSE

				filtered_uplink_items["Discounted Team Gear"] = nuclear_team.team_discounts["Discounted Team Gear"]
				filtered_uplink_items["Limited Stock Team Gear"] = nuclear_team.team_discounts["Limited Stock Team Gear"]


	return filtered_uplink_items

/proc/create_uplink_sales(num, category_name, limited_stock, sale_items, uplink_items)
	if (num <= 0)
		return

	if(!uplink_items[category_name])
		uplink_items[category_name] = list()

	for (var/i in 1 to num)
		var/datum/uplink_item/I = pick_n_take(sale_items)
		var/datum/uplink_item/A = new I.type
		var/discount = A.get_discount()
		var/list/disclaimer = list("Void where prohibited.", "Not recommended for children.", "Contains small parts.", "Check local laws for legality in region.", "Do not taunt.", "Not responsible for direct, indirect, incidental or consequential damages resulting from any defect, error or failure to perform.", "Keep away from fire or flames.", "Product is provided \"as is\" without any implied or expressed warranties.", "As seen on TV.", "For recreational use only.", "Use only as directed.", "16% sales tax will be charged for orders originating within Space Nebraska.")
		A.limited_stock = limited_stock
		I.refundable = FALSE //THIS MAN USES ONE WEIRD TRICK TO GAIN FREE TC, CODERS HATES HIM!
		A.refundable = FALSE
		if(A.cost >= 20) //Tough love for nuke ops
			discount *= 0.5
		A.category = category_name
		A.cost = max(round(A.cost * discount),1)
		A.name += " ([round(((initial(A.cost)-A.cost)/initial(A.cost))*100)]% off!)"
		A.desc += " Normally costs [initial(A.cost)] TC. All sales final. [pick(disclaimer)]"
		A.item = I.item

		uplink_items[category_name][A.name] = A


/**
 * Uplink Items
 *
 * Items that can be spawned from an uplink. Can be limited by gamemode.
**/
/datum/uplink_item
	var/name = "item name"
	var/category = "item category"
	var/desc = "item description"
	var/item = null // Path to the item to spawn.
	var/refund_path = null // Alternative path for refunds, in case the item purchased isn't what is actually refunded (ie: holoparasites).
	var/cost = 0
	var/refund_amount = 0 // specified refund amount in case there needs to be a TC penalty for refunds.
	var/refundable = FALSE
	var/surplus = 100 // Chance of being included in the surplus crate.
	var/cant_discount = FALSE
	var/limited_stock = -1 //Setting this above zero limits how many times this item can be bought by the same traitor in a round, -1 is unlimited
	var/list/include_modes = list() // Game modes to allow this item in.
	var/list/exclude_modes = list() // Game modes to disallow this item from.
	var/list/restricted_roles = list() //If this uplink item is only available to certain roles. Roles are dependent on the frequency chip or stored ID.
	var/player_minimum //The minimum crew size needed for this item to be added to uplinks.
	var/purchase_log_vis = TRUE // Visible in the purchase log?
	var/restricted = FALSE // Adds restrictions for VR/Events
	var/list/restricted_species //Limits items to a specific species. Hopefully.
	var/illegal_tech = TRUE // Can this item be deconstructed to unlock certain techweb research nodes?

/datum/uplink_item/proc/get_discount()
	return pick(4;0.75,2;0.5,1;0.25)

/datum/uplink_item/proc/purchase(mob/user, datum/component/uplink/U)
	var/atom/A = spawn_item(item, user, U)
	if(purchase_log_vis && U.purchase_log)
		U.purchase_log.LogPurchase(A, src, cost)

/datum/uplink_item/proc/spawn_item(spawn_path, mob/user, datum/component/uplink/U)
	if(!spawn_path)
		return
	var/atom/A
	if(ispath(spawn_path))
		A = new spawn_path(get_turf(user))
	else
		A = spawn_path
	if(ishuman(user) && istype(A, /obj/item))
		var/mob/living/carbon/human/H = user
		if(H.put_in_hands(A))
			to_chat(H, "<span class='boldnotice'>[A] materializes into your hands!</span>")
			return A
	to_chat(user, "<span class='boldnotice'>[A] materializes onto the floor!</span>")
	return A

//Discounts (dynamically filled above)
/datum/uplink_item/discounts
	category = "Discounts"

//All bundles and telecrystals
/datum/uplink_item/bundles_tc
	category = "Bundles"
	surplus = 0
	cant_discount = TRUE

/datum/uplink_item/bundles_tc/chemical
	name = "Bioterror bundle"
	desc = "For the madman: Contains a handheld Bioterror chem sprayer, a Bioterror foam grenade, a box of lethal chemicals, a dart pistol, \
			box of syringes, Donksoft assault rifle, and some riot darts. Remember: Seal suit and equip internals before use."
	item = /obj/item/storage/backpack/duffelbag/syndie/med/bioterrorbundle
	cost = 30 // normally 42
	include_modes = list(/datum/game_mode/nuclear, /datum/game_mode/nuclear/clown_ops)

/datum/uplink_item/bundles_tc/bulldog
	name = "Bulldog bundle"
	desc = "Lean and mean: Optimized for people that want to get up close and personal. Contains the popular \
			Bulldog shotgun, two 12g buckshot drums, and a pair of Thermal imaging goggles."
	item = /obj/item/storage/backpack/duffelbag/syndie/bulldogbundle
	cost = 13 // normally 16
	include_modes = list(/datum/game_mode/nuclear)

/datum/uplink_item/bundles_tc/c20r
	name = "C-20r bundle"
	desc = "Old Faithful: The classic C-20r, bundled with two magazines and a (surplus) suppressor at discount price."
	item = /obj/item/storage/backpack/duffelbag/syndie/c20rbundle
	cost = 14 // normally 16
	include_modes = list(/datum/game_mode/nuclear)

/datum/uplink_item/bundles_tc/cyber_implants
	name = "Cybernetic Implants Bundle"
	desc = "A random selection of cybernetic implants. Guaranteed 5 high quality implants. Comes with an autosurgeon."
	item = /obj/item/storage/box/cyber_implants
	cost = 40
	include_modes = list(/datum/game_mode/nuclear)

/datum/uplink_item/bundles_tc/medical
	name = "Medical bundle"
	desc = "The support specialist: Aid your fellow operatives with this medical bundle. Contains a tactical medkit, \
			a Donksoft LMG, a box of riot darts and a pair of magboots to rescue your friends in no-gravity environments."
	item = /obj/item/storage/backpack/duffelbag/syndie/med/medicalbundle
	cost = 15 // normally 20
	include_modes = list(/datum/game_mode/nuclear)

/datum/uplink_item/bundles_tc/sniper
	name = "Sniper bundle"
	desc = "Elegant and refined: Contains a collapsed sniper rifle in an expensive carrying case, \
			two soporific knockout magazines, a free surplus suppressor, and a sharp-looking tactical turtleneck suit. \
			We'll throw in a free red tie if you order NOW."
	item = /obj/item/storage/briefcase/sniperbundle
	cost = 20 // normally 26
	include_modes = list(/datum/game_mode/nuclear)

/datum/uplink_item/bundles_tc/firestarter
	name = "Spetsnaz Pyro bundle"
	desc = "For systematic suppression of carbon lifeforms in close quarters: Contains a lethal New Russian backpack spray, Elite hardsuit, \
			Stechkin APS machine pistol, two incendiary magazines, a minibomb and a stimulant syringe. \
			Order NOW and comrade Boris will throw in an extra tracksuit."
	item = /obj/item/storage/backpack/duffelbag/syndie/firestarter
	cost = 30
	include_modes = list(/datum/game_mode/nuclear)

/datum/uplink_item/bundles_tc/bundle_a
	name = "Syndi-kit Tactical"
	desc = "Syndicate Bundles, also known as Syndi-Kits, are specialized groups of items that arrive in a plain box. \
			These items are collectively worth more than 20 telecrystals, but you do not know which specialization \
			you will receive. May contain discontinued and/or exotic items."
	item = /obj/item/storage/box/syndicate/bundle_a
	cost = 20
	exclude_modes = list(/datum/game_mode/nuclear, /datum/game_mode/nuclear/clown_ops)

/datum/uplink_item/bundles_tc/bundle_b
	name = "Syndi-kit Special"
	desc = "Syndicate Bundles, also known as Syndi-Kits, are specialized groups of items that arrive in a plain box. \
			In Syndi-kit Special, you will receive items used by famous syndicate agents of the past. Collectively worth more than 20 telecrystals, the syndicate loves a good throwback."
	item = /obj/item/storage/box/syndicate/bundle_b
	cost = 20
	exclude_modes = list(/datum/game_mode/nuclear, /datum/game_mode/nuclear/clown_ops)

/datum/uplink_item/bundles_tc/surplus
	name = "Syndicate Surplus Crate"
	desc = "A dusty crate from the back of the Syndicate warehouse. Rumored to contain a valuable assortment of items, \
			but you never know. Contents are sorted to always be worth 50 TC."
	item = /obj/structure/closet/crate
	cost = 20
	player_minimum = 25
	exclude_modes = list(/datum/game_mode/nuclear, /datum/game_mode/nuclear/clown_ops)
	var/starting_crate_value = 50

/datum/uplink_item/bundles_tc/surplus/super
	name = "Super Surplus Crate"
	desc = "A dusty SUPER-SIZED from the back of the Syndicate warehouse. Rumored to contain a valuable assortment of items, \
			but you never know. Contents are sorted to always be worth 125 TC."
	cost = 40
	player_minimum = 40
	starting_crate_value = 125

/datum/uplink_item/bundles_tc/surplus/purchase(mob/user, datum/component/uplink/U)
	var/list/uplink_items = get_uplink_items(SSticker && SSticker.mode? SSticker.mode : null, FALSE)

	var/crate_value = starting_crate_value
	var/obj/structure/closet/crate/C = spawn_item(/obj/structure/closet/crate, user, U)
	if(U.purchase_log)
		U.purchase_log.LogPurchase(C, src, cost)
	while(crate_value)
		var/category = pick(uplink_items)
		var/item = pick(uplink_items[category])
		var/datum/uplink_item/I = uplink_items[category][item]

		if(!I.surplus || prob(100 - I.surplus))
			continue
		if(crate_value < I.cost)
			continue
		crate_value -= I.cost
		var/obj/goods = new I.item(C)
		if(U.purchase_log)
			U.purchase_log.LogPurchase(goods, I, 0)
	return C

/datum/uplink_item/bundles_tc/random
	name = "Random Item"
	desc = "Picking this will purchase a random item. Useful if you have some TC to spare or if you haven't decided on a strategy yet."
	item = /obj/effect/gibspawner/generic // non-tangible item because techwebs use this path to determine illegal tech
	cost = 0

/datum/uplink_item/bundles_tc/random/purchase(mob/user, datum/component/uplink/U)
	var/list/uplink_items = U.uplink_items
	var/list/possible_items = list()
	for(var/category in uplink_items)
		for(var/item in uplink_items[category])
			var/datum/uplink_item/I = uplink_items[category][item]
			if(src == I || !I.item)
				continue
			if(U.telecrystals < I.cost)
				continue
			if(I.limited_stock == 0)
				continue
			possible_items += I

	if(possible_items.len)
		var/datum/uplink_item/I = pick(possible_items)
		SSblackbox.record_feedback("tally", "traitor_random_uplink_items_gotten", 1, initial(I.name))
		U.MakePurchase(user, I)

/datum/uplink_item/bundles_tc/telecrystal
	name = "1 Raw Telecrystal"
	desc = "A telecrystal in its rawest and purest form; can be utilized on active uplinks to increase their telecrystal count."
	item = /obj/item/stack/telecrystal
	cost = 1
	// Don't add telecrystals to the purchase_log since
	// it's just used to buy more items (including itself!)
	purchase_log_vis = FALSE

/datum/uplink_item/bundles_tc/telecrystal/five
	name = "5 Raw Telecrystals"
	desc = "Five telecrystals in their rawest and purest form; can be utilized on active uplinks to increase their telecrystal count."
	item = /obj/item/stack/telecrystal/five
	cost = 5

/datum/uplink_item/bundles_tc/telecrystal/twenty
	name = "20 Raw Telecrystals"
	desc = "Twenty telecrystals in their rawest and purest form; can be utilized on active uplinks to increase their telecrystal count."
	item = /obj/item/stack/telecrystal/twenty
	cost = 20

// Dangerous Items
/datum/uplink_item/dangerous
	category = "Conspicuous Weapons"

/datum/uplink_item/dangerous/throwingweapons
	name = "Box of Throwing Weapons"
	desc = "A box of shurikens and reinforced bolas from ancient Earth martial arts. They are highly effective \
			throwing weapons. The bolas can knock a target down and the shurikens will embed into limbs."
	item = /obj/item/storage/box/syndie_kit/throwing_weapons
	cost = 3
	illegal_tech = FALSE

/datum/uplink_item/dangerous/boomerang
	name = "OZtek Boomerang"
	desc = "Allow user to stun his targets from the distance. Uses power cells to work."
	item = /obj/item/melee/baton/boomerang/loaded
	cost = 3

/datum/uplink_item/dangerous/rapid
	name = "Gloves of the North Star"
	desc = "These gloves let the user punch people very fast. Does not improve weapon attack speed or the meaty fists of a hulk."
	item = /obj/item/clothing/gloves/rapid
	cost = 2

/datum/uplink_item/dangerous/foamsmg
	name = "Toy Submachine Gun"
	desc = "A fully-loaded Donksoft bullpup submachine gun that fires riot grade darts with a 20-round magazine."
	item = /obj/item/gun/ballistic/automatic/c20r/toy
	cost = 4
	surplus = 0

/datum/uplink_item/dangerous/foampistol
	name = "Toy Pistol with Riot Darts"
	desc = "An innocent-looking toy pistol designed to fire foam darts. Comes loaded with riot-grade \
			darts effective at incapacitating a target."
	item = /obj/item/gun/ballistic/automatic/toy/pistol/riot
	cost = 2

/datum/uplink_item/dangerous/minigun
	name = "Minigun Pack"
	desc = "A freaking doom machine, that requires to be worn on the back to use the minigun."
	item = /obj/item/minigunpack
	cost = 7

// Stealthy Weapons
/datum/uplink_item/stealthy_weapons
	category = "Stealthy Weapons"

/datum/uplink_item/stealthy_weapons/cqc
	name = "CQC Manual"
	desc = "A manual that teaches a single user tactical Close-Quarters Combat before self-destructing."
	item = /obj/item/book/granter/martial/cqc
	include_modes = list(/datum/game_mode/nuclear, /datum/game_mode/nuclear/clown_ops)
	cost = 3
	surplus = 0

/datum/uplink_item/stealthy_weapons/martialarts
	name = "Martial Arts Scroll"
	desc = "This scroll contains the secrets of an ancient martial arts technique. You will master unarmed combat \
			and gain the ability to swat bullets from the air, but you will also refuse to use dishonorable ranged weaponry."
	item = /obj/item/book/granter/martial/carp
	cost = 7
	surplus = 0
	exclude_modes = list(/datum/game_mode/nuclear, /datum/game_mode/nuclear/clown_ops)

/datum/uplink_item/stealthy_weapons/sleepy_pen
	name = "Sleepy Pen"
	desc = "A syringe disguised as a functional pen, filled with a potent mix of drugs, including a \
			strong anesthetic and a chemical that prevents the target from speaking. \
			The pen holds one dose of the mixture, and can be refilled with any chemicals. Note that before the target \
			falls asleep, they will be able to move and act."
	item = /obj/item/pen/sleepy
	cost = 2
	exclude_modes = list(/datum/game_mode/nuclear, /datum/game_mode/nuclear/clown_ops)

// Ammunition
/datum/uplink_item/ammo
	category = "Ammunition"
	surplus = 40

/datum/uplink_item/ammo/toydarts
	name = "Box of Riot Darts"
	desc = "A box of 40 Donksoft riot darts, for reloading any compatible foam dart magazine. Don't forget to share!"
	item = /obj/item/ammo_box/foambox/riot
	cost = 1
	surplus = 0
	illegal_tech = FALSE

//Grenades and Explosives
/datum/uplink_item/explosives
	category = "Explosives"

/datum/uplink_item/explosives/c4
	name = "Composition C-4"
	desc = "C-4 is plastic explosive of the common variety Composition C. You can use it to breach walls, sabotage equipment, or connect \
			an assembly to it in order to alter the way it detonates. It can be attached to almost all objects and has a modifiable timer with a \
			minimum setting of 10 seconds."
	item = /obj/item/grenade/c4
	cost = 1

/datum/uplink_item/explosives/pizza_bomb
	name = "Pizza Bomb"
	desc = "A pizza box with a bomb cunningly attached to the lid. The timer needs to be set by opening the box; afterwards, \
			opening the box again will trigger the detonation after the timer has elapsed. Comes with free pizza, for you or your target!"
	item = /obj/item/pizzabox/bomb
	cost = 2
	surplus = 8

/datum/uplink_item/explosives/soap_clusterbang
	name = "Slipocalypse Clusterbang"
	desc = "A traditional clusterbang grenade with a payload consisting entirely of Syndicate soap. Useful in any scenario!"
	item = /obj/item/grenade/clusterbuster/soap
	cost = 2

/datum/uplink_item/explosives/syndicate_bomb
	name = "Syndicate Bomb"
	desc = "The Syndicate bomb is a fearsome device capable of massive destruction. It has an adjustable timer, \
			with a minimum of 60 seconds, and can be bolted to the floor with a wrench to prevent \
			movement. The bomb is bulky and cannot be moved; upon ordering this item, a smaller beacon will be \
			transported to you that will teleport the actual bomb to it upon activation. Note that this bomb can \
			be defused, and some crew may attempt to do so. \
			The bomb core can be pried out and manually detonated with other explosives."
	item = /obj/item/sbeacondrop/bomb
	cost = 4

/datum/uplink_item/explosives/syndicate_bomb/emp
	name = "Syndicate EMP Bomb"
	desc = "A variation of the syndicate bomb designed to produce a large EMP effect."
	item = /obj/item/sbeacondrop/emp
	cost = 4

//Support and Mechs
/datum/uplink_item/support
	category = "Support and Exosuits"
	surplus = 0
	include_modes = list(/datum/game_mode/nuclear)

/datum/uplink_item/support/clown_reinforcement
	name = "Clown Reinforcements"
	desc = "Call in an additional clown to share the fun, equipped with full starting gear, but no telecrystals."
	item = /obj/item/antag_spawner/nuke_ops/clown
	cost = 20
	include_modes = list(/datum/game_mode/nuclear/clown_ops)
	restricted = TRUE

/datum/uplink_item/support/reinforcement
	name = "Reinforcements"
	desc = "Call in an additional team member. They won't come with any gear, so you'll have to save some telecrystals \
			to arm them as well."
	item = /obj/item/antag_spawner/nuke_ops
	cost = 25
	refundable = TRUE
	include_modes = list(/datum/game_mode/nuclear)
	restricted = TRUE

/datum/uplink_item/support/reinforcement/assault_borg
	name = "Syndicate Assault Cyborg"
	desc = "A cyborg designed and programmed for systematic extermination of non-Syndicate personnel. \
			Comes equipped with a self-resupplying LMG, a grenade launcher, energy sword, emag, pinpointer, flash and crowbar."
	item = /obj/item/antag_spawner/nuke_ops/borg_tele/assault
	refundable = TRUE
	cost = 65
	restricted = TRUE

/datum/uplink_item/support/reinforcement/medical_borg
	name = "Syndicate Medical Cyborg"
	desc = "A combat medical cyborg. Has limited offensive potential, but makes more than up for it with its support capabilities. \
			It comes equipped with a nanite hypospray, a medical beamgun, combat defibrillator, full surgical kit including an energy saw, an emag, pinpointer and flash. \
			Thanks to its organ storage bag, it can perform surgery as well as any humanoid."
	item = /obj/item/antag_spawner/nuke_ops/borg_tele/medical
	refundable = TRUE
	cost = 35
	restricted = TRUE

/datum/uplink_item/support/reinforcement/saboteur_borg
	name = "Syndicate Saboteur Cyborg"
	desc = "A streamlined engineering cyborg, equipped with covert modules. Also incapable of leaving the welder in the shuttle. \
			Aside from regular Engineering equipment, it comes with a special destination tagger that lets it traverse disposals networks. \
			Its chameleon projector lets it disguise itself as a Nanotrasen cyborg, on top it has thermal vision and a pinpointer."
	item = /obj/item/antag_spawner/nuke_ops/borg_tele/saboteur
	refundable = TRUE
	cost = 35
	restricted = TRUE

/datum/uplink_item/support/gygax
	name = "Dark Gygax Exosuit"
	desc = "A lightweight exosuit, painted in a dark scheme. Its speed and equipment selection make it excellent \
			for hit-and-run style attacks. Features an incendiary carbine, flash bang launcher, teleporter, ion thrusters and a Tesla energy array."
	item = /obj/vehicle/sealed/mecha/combat/gygax/dark/loaded
	cost = 80

/datum/uplink_item/support/honker
	name = "Dark H.O.N.K."
	desc = "A clown combat mech equipped with bombanana peel and tearstache grenade launchers, as well as the ubiquitous HoNkER BlAsT 5000."
	item = /obj/vehicle/sealed/mecha/combat/honker/dark/loaded
	cost = 80
	include_modes = list(/datum/game_mode/nuclear/clown_ops)

/datum/uplink_item/support/mauler
	name = "Mauler Exosuit"
	desc = "A massive and incredibly deadly military-grade exosuit. Features long-range targeting, thrust vectoring \
			and deployable smoke. Comes equipped with an LMG, scattershot carbine, missile rack, an antiprojectile armor booster and a Tesla energy array."
	item = /obj/vehicle/sealed/mecha/combat/marauder/mauler/loaded
	cost = 140

// Stealth Items
/datum/uplink_item/stealthy_tools
	category = "Stealth Gadgets"

/datum/uplink_item/stealthy_tools/agent_card
	name = "Agent Identification Card"
	desc = "Agent cards prevent artificial intelligences from tracking the wearer, and can copy access \
			from other identification cards. The access is cumulative, so scanning one card does not erase the \
			access gained from another. In addition, they can be forged to display a new assignment and name. \
			This can be done an unlimited amount of times. Some Syndicate areas and devices can only be accessed \
			with these cards."
	item = /obj/item/card/id/syndicate
	cost = 1

/datum/uplink_item/stealthy_tools/chameleon
	name = "Chameleon Kit"
	desc = "A set of items that contain chameleon technology allowing you to disguise as pretty much anything on the station, and more! \
			Due to budget cuts, the shoes don't provide protection against slipping and skillchips are sold separately."
	item = /obj/item/storage/box/syndie_kit/chameleon
	cost = 1
	exclude_modes = list(/datum/game_mode/nuclear) //clown ops are allowed to buy this kit, since it's basically a costume

/datum/uplink_item/stealthy_tools/chameleon_proj
	name = "Chameleon Projector"
	desc = "Projects an image across a user, disguising them as an object scanned with it, as long as they don't \
			move the projector from their hand. Disguised users move slowly, and projectiles pass over them."
	item = /obj/item/chameleon
	cost = 3

/datum/uplink_item/stealthy_tools/mulligan
	name = "Mulligan"
	desc = "Screwed up and have security on your tail? This handy syringe will give you a completely new identity \
			and appearance."
	item = /obj/item/reagent_containers/syringe/mulligan
	cost = 1
	surplus = 30

/datum/uplink_item/stealthy_tools/knife
	name = "Poisoned Knife"
	desc = "Poisoned survival knife, that deals incredibly much toxin damage to victim."
	item = /obj/item/kitchen/knife/combat/poisoned
	cost = 2

/datum/uplink_item/stealthy_tools/syndigaloshes
	name = "No-Slip Chameleon Shoes"
	desc = "These shoes will allow the wearer to run on wet floors and slippery objects without falling down. \
			They do not work on heavily lubricated surfaces."
	item = /obj/item/clothing/shoes/chameleon/noslip
	cost = 1
	exclude_modes = list(/datum/game_mode/nuclear, /datum/game_mode/nuclear/clown_ops)

//Space Suits and Hardsuits
/datum/uplink_item/suits
	category = "Space Suits"
	surplus = 40

/datum/uplink_item/suits/infiltrator_bundle
	name = "Infiltrator Case"
	desc = "Developed by Roseus Galactic in conjunction with the Gorlex Marauders to produce a functional suit for urban operations, \
			this suit proves to be cheaper than your standard issue hardsuit, with none of the movement restrictions of the outdated spacesuits employed by the company. \
			Comes with an armor vest, helmet, sneaksuit, sneakboots, specialized combat gloves and a high-tech balaclava. The case is also rather useful as a storage container."
	item = /obj/item/storage/toolbox/infiltrator
	cost = 5
	limited_stock = 1 //you only get one so you don't end up with too many gun cases
	exclude_modes = list(/datum/game_mode/nuclear, /datum/game_mode/nuclear/clown_ops)

// Devices and Tools
/datum/uplink_item/device_tools
	category = "Misc. Gadgets"

/datum/uplink_item/device_tools/emag
	name = "Cryptographic Sequencer"
	desc = "The cryptographic sequencer, electromagnetic card, or emag, is a small card that unlocks hidden functions \
			in electronic devices, subverts intended functions, and easily breaks security mechanisms. Cannot be used to open airlocks."
	item = /obj/item/card/emag
	cost = 4

/datum/uplink_item/device_tools/failsafe
	name = "Failsafe Uplink Code"
	desc = "When entered the uplink will self-destruct immediately."
	item = /obj/effect/gibspawner/generic
	cost = 1
	surplus = 0
	restricted = TRUE
	exclude_modes = list(/datum/game_mode/nuclear, /datum/game_mode/nuclear/clown_ops)

/datum/uplink_item/device_tools/failsafe/spawn_item(spawn_path, mob/user, datum/component/uplink/U)
	if(!U)
		return
	U.failsafe_code = U.generate_code()
	var/code = "[islist(U.failsafe_code) ? english_list(U.failsafe_code) : U.failsafe_code]"
	to_chat(user, "<span class='warning'>The new failsafe code for this uplink is now : [code].</span>")
	if(user.mind)
		user.mind.store_memory("Failsafe code for [U.parent] : [code]")
	return U.parent //For log icon

/datum/uplink_item/device_tools/toolbox
	name = "Full Syndicate Toolbox"
	desc = "The Syndicate toolbox is a suspicious black and red. It comes loaded with a full tool set including a \
			multitool and combat gloves that are resistant to shocks and heat."
	item = /obj/item/storage/toolbox/syndicate
	cost = 1
	illegal_tech = FALSE

/datum/uplink_item/device_tools/hypnotic_flash
	name = "Hypnotic Flash"
	desc = "A modified flash able to hypnotize targets. If the target is not in a mentally vulnerable state, it will only confuse and pacify them temporarily."
	item = /obj/item/assembly/flash/hypnotic
	cost = 5

/datum/uplink_item/device_tools/hypnotic_grenade
	name = "Hypnotic Grenade"
	desc = "A modified flashbang grenade able to hypnotize targets. The sound portion of the flashbang causes hallucinations, and will allow the flash to induce a hypnotic trance to viewers."
	item = /obj/item/grenade/hypnotic
	cost = 7

/datum/uplink_item/device_tools/medkit
	name = "Syndicate Combat Medic Kit"
	desc = "This first aid kit is a suspicious brown and red. Included is a combat stimulant injector \
			for rapid healing, a medical night vision HUD for quick identification of injured personnel, \
			and other supplies helpful for a field medic."
	item = /obj/item/storage/firstaid/tactical
	cost = 3

/datum/uplink_item/device_tools/soap
	name = "Syndicate Soap"
	desc = "A sinister-looking surfactant used to clean blood stains to hide murders and prevent DNA analysis. \
			You can also drop it underfoot to slip people."
	item = /obj/item/soap/syndie
	cost = 1
	surplus = 50
	illegal_tech = FALSE

/datum/uplink_item/device_tools/surgerybag
	name = "Syndicate Surgery Duffel Bag"
	desc = "The Syndicate surgery duffel bag is a toolkit containing all surgery tools, surgical drapes, \
			a Syndicate brand MMI, a straitjacket, and a muzzle."
	item = /obj/item/storage/backpack/duffelbag/syndie/surgery
	cost = 2

/datum/uplink_item/device_tools/encryptionkey
	name = "Syndicate Encryption Key"
	desc = "A key that, when inserted into a radio headset, allows you to listen to all station department channels \
			as well as talk on an encrypted Syndicate channel with other agents that have the same key."
	item = /obj/item/encryptionkey/syndicate
	cost = 1
	surplus = 75
	restricted = TRUE

/datum/uplink_item/device_tools/syndietome
	name = "Syndicate Tome"
	desc = "Using rare artifacts acquired at great cost, the Syndicate has reverse engineered \
			the seemingly magical books of a certain cult. Though lacking the esoteric abilities \
			of the originals, these inferior copies are still quite useful, being able to provide \
			both weal and woe on the battlefield, even if they do occasionally bite off a finger."
	item = /obj/item/storage/book/bible/syndicate
	cost = 1

/datum/uplink_item/device_tools/thermal
	name = "Thermal Imaging Glasses"
	desc = "These goggles can be turned to resemble common eyewear found throughout the station. \
			They allow you to see organisms through walls by capturing the upper portion of the infrared light spectrum, \
			emitted as heat and light by objects. Hotter objects, such as warm bodies, cybernetic organisms \
			and artificial intelligence cores emit more of this light than cooler objects like walls and airlocks."
	item = /obj/item/clothing/glasses/thermal/syndi
	cost = 4

/datum/uplink_item/device_tools/guerillagloves
	name = "Guerilla Gloves"
	desc = "A pair of highly robust combat gripper gloves that excels at performing takedowns at close range, with an added lining of insulation. Careful not to hit a wall!"
	item = /obj/item/clothing/gloves/tackler/combat/insulated
	include_modes = list(/datum/game_mode/nuclear, /datum/game_mode/nuclear/clown_ops)
	cost = 2
	illegal_tech = FALSE

// Implants
/datum/uplink_item/implants
	category = "Implants"
	surplus = 50

/datum/uplink_item/implants/antistun
	name = "CNS Rebooter Implant"
	desc = "This implant will help you get back up on your feet faster after being stunned. Comes with an autosurgeon."
	item = /obj/item/autosurgeon/organ/syndicate/anti_stun
	cost = 3
	surplus = 0
	include_modes = list(/datum/game_mode/nuclear)

/datum/uplink_item/implants/freedom
	name = "Freedom Implant"
	desc = "An implant injected into the body and later activated at the user's will. It will attempt to free the \
			user from common restraints such as handcuffs."
	item = /obj/item/storage/box/syndie_kit/imp_freedom
	cost = 1

/datum/uplink_item/implants/storage
	name = "Storage Implant"
	desc = "An implant injected into the body, and later activated at the user's will. It will open a small bluespace \
			pocket capable of storing two regular-sized items."
	item = /obj/item/storage/box/syndie_kit/imp_storage
	cost = 2


//Race-specific items
/datum/uplink_item/race_restricted
	category = "Species-Restricted"
	exclude_modes = list(/datum/game_mode/nuclear, /datum/game_mode/nuclear/clown_ops)
	surplus = 0

/datum/uplink_item/race_restricted/syndilamp
	name = "Extra-Bright Lantern"
	desc = "We heard that moths such as yourself really like lamps, so we decided to grant you early access to a prototype \
	Syndicate brand \"Extra-Bright Lantern™\". Enjoy."
	cost = 1
	item = /obj/item/flashlight/lantern/syndicate
	restricted_species = list("moth")

// Role-specific items
/datum/uplink_item/role_restricted
	category = "Role-Restricted"
	exclude_modes = list(/datum/game_mode/nuclear, /datum/game_mode/nuclear/clown_ops)
	surplus = 0

/datum/uplink_item/role_restricted/turretbox
	name = "Disposable Sentry Gun"
	desc = "A disposable sentry gun deployment system cleverly disguised as a toolbox, apply wrench for functionality."
	item = /obj/item/storage/toolbox/emergency/turret
	cost = 11
	restricted_roles = list("Station Engineer")

// Pointless
/datum/uplink_item/badass
	category = "(Pointless) Badassery"
	surplus = 0

/datum/uplink_item/badass/costumes/obvious_chameleon
	name = "Broken Chameleon Kit"
	desc = "A set of items that contain chameleon technology allowing you to disguise as pretty much anything on the station, and more! \
			Please note that this kit did NOT pass quality control."
	item = /obj/item/storage/box/syndie_kit/chameleon/broken

/datum/uplink_item/badass/costumes
	surplus = 0
	include_modes = list(/datum/game_mode/nuclear, /datum/game_mode/nuclear/clown_ops)
	cost = 4
	cant_discount = TRUE

/datum/uplink_item/badass/costumes/centcom_official
	name = "CentCom Official Costume"
	desc = "Ask the crew to \"inspect\" their nuclear disk and weapons system, and then when they decline, pull out a fully automatic rifle and gun down the Captain. \
			Radio headset does not include encryption key. No gun included."
	item = /obj/item/storage/box/syndie_kit/centcom_costume

/datum/uplink_item/badass/costumes/clown
	name = "Clown Costume"
	desc = "Nothing is more terrifying than clowns with fully automatic weaponry."
	item = /obj/item/storage/backpack/duffelbag/clown/syndie

/datum/uplink_item/badass/costumes/tactical_naptime
	name = "Sleepy Time Pajama Bundle"
	desc = "Even soldiers need to get a good nights rest. Comes with blood-red pajamas, a blankie, a hot mug of cocoa and a fuzzy friend."
	item = /obj/item/storage/box/syndie_kit/sleepytime
	cost = 4
	limited_stock = 1
	cant_discount = TRUE

/datum/uplink_item/badass/balloon
	name = "Syndicate Balloon"
	desc = "For showing that you are THE BOSS: A useless red balloon with the Syndicate logo on it. \
			Can blow the deepest of covers."
	item = /obj/item/toy/balloon/syndicate
	cost = 5
	cant_discount = TRUE
	illegal_tech = FALSE

/datum/uplink_item/badass/syndiecash
	name = "Syndicate Briefcase Full of Cash"
	desc = "A secure briefcase containing 5000 space credits. Useful for bribing personnel, or purchasing goods \
			and services at lucrative prices. The briefcase also feels a little heavier to hold; it has been \
			manufactured to pack a little bit more of a punch if your client needs some convincing."
	item = /obj/item/storage/secure/briefcase/syndie
	cost = 1
	restricted = TRUE
	illegal_tech = FALSE

/datum/uplink_item/badass/syndiecards
	name = "Syndicate Playing Cards"
	desc = "A special deck of space-grade playing cards with a mono-molecular edge and metal reinforcement, \
			making them slightly more robust than a normal deck of cards. \
			You can also play card games with them or leave them on your victims."
	item = /obj/item/toy/cards/deck/syndicate
	cost = 1
	surplus = 40
	illegal_tech = FALSE

/datum/uplink_item/badass/syndiecigs
	name = "Syndicate Smokes"
	desc = "Strong flavor, dense smoke, infused with omnizine."
	item = /obj/item/storage/fancy/cigarettes/cigpack_syndicate
	cost = 2
	illegal_tech = FALSE

/datum/uplink_item/badass/dice
	name = "Dice Of Fate"
	desc = "Disposable dice of fate, allowing you to try your luck before death."
	item = /obj/item/dice/d20/fate/one_use
	cost = 3

/datum/uplink_item/badass/clownopclumsinessinjector //clowns can buy this too, but it's in the role-restricted items section for them
	name = "Clumsiness Injector"
	desc = "Inject yourself with this to become as clumsy as a clown... or inject someone ELSE with it to make THEM as clumsy as a clown. Useful for clown operatives who wish to reconnect with their former clownish nature or for clown operatives who wish to torment and play with their prey before killing them."
	item = /obj/item/dnainjector/clumsymut
	cost = 1
	include_modes = list(/datum/game_mode/nuclear/clown_ops)
	illegal_tech = FALSE

