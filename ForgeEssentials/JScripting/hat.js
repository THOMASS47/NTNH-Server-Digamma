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

	var inv = args.player.getInventory()
	var currentItem = inv.getCurrentItem()
	var currentItemIndex = inv.getCurrentItemIndex()

	var helmetSlot = 40
	var chestplateSlot = 39
	var leggingsSlot = 38
	var bootsSlot = 37

	var armorSlot
	if (args.isEmpty() || args.get(0) == "helmet") armorSlot = helmetSlot
	else if (args.get(0) == "chestplate") armorSlot = chestplateSlot
	else if (args.get(0) == "leggings") armorSlot = leggingsSlot
	else if (args.get(0) == "boots") armorSlot = bootsSlot
	var armorItem = inv.getStackInSlot(armorSlot)

	if (currentItem == null) {
		args.error("Not holding an item")
		return
	}

	if (armorItem == null) {
		inv.setStackInSlot(armorSlot, currentItem)
		inv.setStackInSlot(currentItemIndex, null)
		args.confirm(":)")
	} else {
		inv.setStackInSlot(armorSlot, currentItem)
		inv.setStackInSlot(currentItemIndex, armorItem)
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
