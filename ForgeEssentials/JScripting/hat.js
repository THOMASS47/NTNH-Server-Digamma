function hatCommandHandler(args) {
    if (args.isTabCompletion) {
        return;
    }
    
    // Check if the command sender is a player
    if (!args.hasPlayer()) {
        args.error("Only players can use this command!");
        return;
    }
    
    var player = args.player;
    var inv = player.getInventory();
    
    var currentItem = inv.getCurrentItem();
    var currentItemIndex = inv.getCurrentItemIndex();
    var helmetSlot = inv.getSize() - 1; // Helmet slot is always the last slot in the inventory
    
    var helmetItem = inv.getStackInSlot(helmetSlot);
    
    if (currentItem == null || currentItem.getItem() == null) {
        if (helmetItem != null && helmetItem.getItem() != null) {
            inv.setStackInSlot(currentItemIndex, helmetItem);
            inv.setStackInSlot(helmetSlot, null);
            args.confirm("Hat taken off!");
        } else {
            args.error("Hold an item in your hand to wear it as a hat!");
        }
    } else {
        inv.setStackInSlot(helmetSlot, currentItem);
        inv.setStackInSlot(currentItemIndex, helmetItem);
        args.confirm("Enjoy your new hat!");
    }
}

// Register the command with standard properties matching the wiki guidelines
FEServer.registerCommand({
    name: 'hat',
    usage: '/hat: Wears the item in your hand on your head',
    permission: 'fe.commands.hat',
    opOnly: true, // Restricts command to Operators (OPs) by default
    processCommand: hatCommandHandler,
    tabComplete: hatCommandHandler,
});
