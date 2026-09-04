# NTNH Digamma server

Server repository for the Digamma instance of **Nuclear Tech: New Horizons** 2.14.0, a Minecraft 1.7.10 modpack.

This fork tracks [NTNH-Server](https://github.com/NTNewHorizons/NTNH-Server) while retaining Digamma-specific authentication, administration, configuration, launcher, and branding changes.

> Upstream regenerates `mods/`, `config/`, `scripts/`, and `serverutilities/` for each release. Merge upstream releases into this repository and test them before deploying; do not replace those directories directly on a live Digamma server.

## Requirements

- Java 17 or newer (Java 21 is supported)
- Git with Git LFS
- Linux: `curl` and `sha256sum`; Windows: PowerShell 5.1+
- At least 10 GB of memory available for the configured JVM heap

Java 17+ is required by this fork's LWJGL3ify launch path even though the stock upstream server uses Java 8.

## Install

### Linux

```bash
git clone https://github.com/THOMASS47/NTNH-Server-Digamma.git
cd NTNH-Server-Digamma
./start.sh
```

### Windows

```batch
git clone https://github.com/THOMASS47/NTNH-Server-Digamma.git
cd NTNH-Server-Digamma
start.bat
```

The HBM jar is too large for normal Git storage, so when the checkout contains its pointer, the launcher downloads and verifies it with Git LFS. The launchers then locate Java 17+, read JVM options from `server-args.txt`, and start Forge through LWJGL3ify.

## Updating a deployed server

The deployed server should track this fork's `main` branch, not the upstream distribution archive.

```bash
./start.sh --update
```

The Digamma launcher fetches and applies `origin/main`. Automatic update checks can be enabled with `--auto-update` or `AUTO_UPDATE=true`.

Do not use the stock NTNH release updater on a Digamma instance. It replaces modpack directories wholesale and would remove the fork's custom mods and configuration.

## Java arguments

JVM options are read from `server-args.txt`. To override them for one launch:

```bash
JVM_OPTS="-Xms10G -Xmx10G" ./start.sh
```

Java can be selected with `JAVA_CMD`, `JAVA_PATH`, or `JAVA_HOME`.

## Docker

```bash
cd docker
docker compose up -d
```

The Docker image uses Java 21 and persists the world, backups, logs, and crash reports through volumes.

## Synchronizing upstream

```bash
git fetch upstream
git switch -c merge/upstream-<version>
GIT_LFS_SKIP_SMUDGE=1 git merge --no-commit --no-ff upstream/main
```

Resolve conflicts by keeping the new upstream modpack payload and reapplying Digamma-specific launch, authentication, ForgeEssentials, server utility, and branding policies. Validate on a staging server before merging to `main`.

## Support

- [NTNH modpack issues](https://github.com/NTNewHorizons/NTNH/issues)
- [Upstream server issues](https://github.com/NTNewHorizons/NTNH-Server/issues)
