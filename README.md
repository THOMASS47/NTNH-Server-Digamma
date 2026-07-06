# NTNH Server

Server-side version of the **Nuclear Tech: New Horizons** modpack for Minecraft 1.7.10.

> ⚠️ This repository is **auto-generated** from the [client repo](https://github.com/NTNewHorizons/NTNH). Files in `mods/`, `config/`, `scripts/`, `serverutilities/` are overwritten on each release.

---

## Quick Start

**Requirements:** Java 8, 4 GB+ RAM

```bash
git clone https://github.com/NTNewHorizons/NTNH-Server.git
cd NTNH-Server
./start.sh
```

That's it. `start.sh` checks Java, accepts the EULA, resolves LFS files, and launches the server.

### Updating

```bash
./start.sh --update
```

Force-syncs all tracked files to the latest upstream version. Your `world/`, `server.properties`, `ops.json`, `whitelist.json`, `logs/`, and other untracked data are never touched.

### Docker

```bash
cd docker
docker compose up -d
```

---

## How It Works

The server pack is generated from the client repo on each release. A GitHub Action strips client-only mods and publishes the result here.

Files you can edit freely (never overwritten):
- `server.properties`, `ops.json`, `whitelist.json`, `banned-*.json`
- `world/`, `logs/`, `crash-reports/`, `backups/`

Files reset on update:
- `mods/`, `config/`, `scripts/`, `serverutilities/`
- `README.md`, `knownkeys.txt`, `localconfig.cfg`

---

## Support

[Bugs & mod issues](https://github.com/NTNewHorizons/NTNH/issues) · [Server issues](https://github.com/NTNewHorizons/NTNH-Server/issues)
