/**
 * @typedef {import('./fe.d.ts')} fe
 * @typedef {import('./mc.d.ts')} mc
 */

/**
 * @param {fe.CommandArgs} args
 */
function tpxCommandHandler(args) {
    if (args.isTabCompletion) {
        try {
            var players = args.player.getWorld().asWorldServer().getPlayerEntities();
            for (var i = 0; i < players.size(); i++) {
                args.tabCompleteWord(players.get(i).getName());
            }
        } catch (e) {
            args.error(e.getMessage());
        }
        return;
    }

    // Proxy the command to /cofh tpx
    var size = args.size();
    if (size == 0) {
        Server.runCommand(args.sender, 'cofh', 'tpx');
    } else if (size == 1) {
        Server.runCommand(args.sender, 'cofh', 'tpx', args.get(0));
    } else if (size == 2) {
        Server.runCommand(args.sender, 'cofh', 'tpx', args.get(0), args.get(1));
    } else if (size == 3) {
        Server.runCommand(args.sender, 'cofh', 'tpx', args.get(0), args.get(1), args.get(2));
    } else if (size == 4) {
        Server.runCommand(args.sender, 'cofh', 'tpx', args.get(0), args.get(1), args.get(2), args.get(3));
    } else {
        Server.runCommand(args.sender, 'cofh', 'tpx', args.get(0), args.get(1), args.get(2), args.get(3), args.get(4));
    }
}

// Register the command with standard properties matching the wiki guidelines
FEServer.registerCommand({
    name: 'tpx',
    usage: '/tpx [player] {{<playerTo> | <dimension>} | <x> <y> <z> [dimension]}',
    permission: 'fe.commands.tpx',
    opOnly: true, // Restricts command to Operators (OPs) by default
    processCommand: tpxCommandHandler,
    tabComplete: tpxCommandHandler,
});
