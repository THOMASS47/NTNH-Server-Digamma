/**
 * @typedef {import('./fe.d.ts')} fe
 * @typedef {import('./mc.d.ts')} mc
 */

/**
 * @param {fe.CommandArgs} args
 */
function hatCommandHandler(args) {
	if (args.isTabCompletion) {
		args.tabComplete("helmet", "chestplate", "leggings", "boots")
		return
	}

	if (!args.hasPlayer()) {
		args.error("Only players can use this command")
		return
	}

	var helmetSlot = 40
	var chestplateSlot = 39
	var leggingsSlot = 38
	var bootsSlot = 37

	var armorSlot = helmetSlot
	var targetPlayer = args.player

	if (!args.isEmpty()) {
		var arg0 = args.get(0)
		if (arg0 == "helmet" || arg0 == "chestplate" || arg0 == "leggings" || arg0 == "boots") {
			if (arg0 == "chestplate") armorSlot = chestplateSlot
			else if (arg0 == "leggings") armorSlot = leggingsSlot
			else if (arg0 == "boots") armorSlot = bootsSlot
			
			if (args.size() > 1) {
				targetPlayer = args.parsePlayer(args.get(1), true, true).getPlayer()
			}
		} else {
			targetPlayer = args.parsePlayer(arg0, true, true).getPlayer()
			if (args.size() > 1) {
				var arg1 = args.get(1)
				if (arg1 == "helmet") armorSlot = helmetSlot
				else if (arg1 == "chestplate") armorSlot = chestplateSlot
				else if (arg1 == "leggings") armorSlot = leggingsSlot
				else if (arg1 == "boots") armorSlot = bootsSlot
				else {
					args.error("Invalid armor slot: " + arg1)
					return
				}
			}
		}
	}

	var callerInv = args.player.getInventory()
	var currentItem = callerInv.getCurrentItem()
	var currentItemIndex = callerInv.getCurrentItemIndex()

	var targetInv = targetPlayer.getInventory()
	var armorItem = targetInv.getStackInSlot(armorSlot)

	if (currentItem == null) {
		args.error("Not holding an item")
		return
	}

	if (armorItem == null) {
		targetInv.setStackInSlot(armorSlot, currentItem)
		callerInv.setStackInSlot(currentItemIndex, null)
		args.confirm(":)")
	} else {
		targetInv.setStackInSlot(armorSlot, currentItem)
		callerInv.setStackInSlot(currentItemIndex, armorItem)
		args.confirm(":)")
	}
}

FEServer.registerCommand({
	name: "hat",
	usage: "/hat: Wears the item in your hand on your head",
	permission: "fe.commands.hat",
	opOnly: true,
	processCommand: hatCommandHandler,
	tabComplete: hatCommandHandler,
})
