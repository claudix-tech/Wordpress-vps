# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Docker-based tool for creating and managing multiple, fully isolated WordPress instances on a single host (each with its own MySQL container, WordPress/Apache container, phpMyAdmin container, network, and ports). There is no application code to build — the "product" is the management tooling and the per-instance Docker Compose configuration it generates.

## Commands

```bash
# Create an instance (auto-detects free ports starting at 8000 if omitted)
python3 wp-manager.py create <name> [wp_port] [pma_port]
./wp-manager.sh create <name> [wp_port] [pma_port]

# Start / stop
python3 wp-manager.py start <name>
python3 wp-manager.py stop <name>

# List all instances with running/stopped status
python3 wp-manager.py list

# Backup (dumps DB via mysqldump + tars wp-content/) into instances/<name>/backups/
python3 wp-manager.py backup <name>

# Delete (docker compose down -v, then removes the instance directory) — prompts for 'yes'
python3 wp-manager.py delete <name>
```

The Bash version (`wp-manager.sh`) implements the identical command set and can be run interactively (no args, shows a numbered menu) or with the same subcommands. `wp-manager.sh` also `set -e`s and shells out to `python3` for its own port-availability checks.

Equivalent `make <target> INSTANCE=<name>` wrappers exist (`create`, `start`, `stop`, `list`, `backup`, `delete`, plus `logs`, `shell-db`, `ps`, `stats`, `clean`) — see `Makefile`. `make test` only checks that Docker/Compose are installed and `wp-manager.py --help` runs; there is no automated test suite for actual instance behavior.

To work with a running instance directly, `cd instances/<name>` and use `docker compose` (or `docker-compose`) as usual.

## Architecture

**Two independent, parity implementations.** `wp-manager.py` (recommended, more portable) and `wp-manager.sh` (bash-only alternative) each re-implement the full create/start/stop/list/backup/delete logic from scratch — neither calls the other. When changing behavior (new .env field, new generated file, changed defaults, etc.), both files need the change or they will drift out of sync. Both auto-detect whether `docker compose` (v2) or `docker-compose` (v1, legacy) is available and use that consistently for the rest of the run.

**Instance = generated directory, not code.** `create` renders the repo-root `*.template` files into a new `instances/<name>/` directory:
- `docker-compose.yml.template` → `instances/<name>/docker-compose.yml`, with every `{{INSTANCE_NAME}}` placeholder replaced by the instance name (Python uses `str.replace`, Bash uses `sed`). This drives the container/network/volume names (`wp-app-<name>`, `wp-db-<name>`, `wp-pma-<name>`, `wordpress_network_<name>`, `mysql_data_<name>`).
- `uploads.ini.template` → `instances/<name>/uploads.ini` (PHP upload/memory limits, mounted into the WordPress container at `/usr/local/etc/php/conf.d/uploads.ini`).
- `apache-limits.conf.template` → `instances/<name>/apache-limits.conf` (mounted at `/etc/apache2/conf-enabled/limits.conf`).
- A fresh `.env` (chmod 600, MySQL credentials generated via `secrets`/`openssl`), a per-instance `README.md`, and a `.dockerignore` are written directly (not templated from a file).

Each instance is otherwise self-contained: its `docker-compose.yml` reads all variable config (ports, DB credentials, table prefix) from its own `.env` via `${VAR}` interpolation, and mounts `./wp-content` for uploads/plugins/themes and `./backups` for dump output.

**The 5GB upload ceiling is defined in three places that must stay consistent**: `WORDPRESS_CONFIG_EXTRA` `ini_set` calls in `docker-compose.yml.template`, `uploads.ini.template`, and `apache-limits.conf.template` (plus `PMA_UPLOAD_LIMIT` for phpMyAdmin in the compose template). Changing the limit means editing all of them — see `ADVANCED.md` for the full list of settings and their purpose.

**Running-instance detection** is done by listing Docker containers and checking for the label `com.wordpress.instance=<name>` (set on the WordPress and phpMyAdmin services in the compose template), not by tracking PIDs or state files.

**`instances/` and `backups/` are gitignored** — they're runtime state created by `create`/`backup`, not source to be committed. Do not treat directories under `instances/` (e.g. any test instances already present) as part of the tracked codebase; nothing under it should be added to git except via a deliberate, explicit request. `.env` files (root-level and per-instance) are also gitignored since they hold generated DB passwords.

## When modifying instance-creation logic

Since `wp-manager.py` and `wp-manager.sh` are hand-kept in sync rather than sharing code, and the templates are plain-text placeholder substitution (not a templating engine), grep both scripts for the thing you're changing (e.g. a new `.env` key, a new generated file) before considering the change complete.
