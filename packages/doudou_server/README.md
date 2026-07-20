# doudou-server

Headless sync server for [doudou](https://gitlab.com/Openlyst/doudou). Holds
library snapshots and music server URLs so multiple doudou clients (phones,
desktops, TVs) can stay in sync from one local server without ever exposing
media server credentials.

## What it stores

- Music server URLs and display metadata (Subsonic / Jellyfin / Plex / YouTube Music)
- Per-music-server library snapshots (songs, playlists, albums, artists)
- Client registrations (which devices have synced)

## What it does NOT store

- Media server passwords. Those stay on each doudou client.
- Audio bytes. Stream URLs are resolved by the client directly against the
  music server.

## Build

```shell
cd packages/doudou_server
flutter build linux   # or macos / windows
```

The resulting binary is a CLI. Run it with `-h` to see options.

## CLI

```shell
doudou-server -start                       # run the server in the foreground
doudou-server -start --host 0.0.0.0 --port 7427
doudou-server -stop                        # stop a running server on this machine
doudou-server -set login <user> <pass>     # set the shared password clients use
doudou-server -status                      # general info
doudou-server -clients                     # list clients that have synced
doudou-server -health                      # probe the running server health endpoint
```

## API

All routes are under `/api/v1` and require the `X-Doudou-Key` header (the
shared password) except `/api/v1/health` which is open.

| Method | Path                      | Purpose                                  |
|--------|---------------------------|------------------------------------------|
| GET    | `/api/v1/health`          | Liveness probe (unauthenticated)         |
| GET    | `/api/v1/servers`         | List music servers                       |
| PUT    | `/api/v1/servers`         | Upsert a music server                    |
| DELETE | `/api/v1/servers/{id}`    | Delete a music server                    |
| GET    | `/api/v1/snapshots`       | List snapshots for `?musicServerId=`     |
| PUT    | `/api/v1/snapshots`       | Push a library snapshot                  |
| POST   | `/api/v1/clients/register`| Register / touch a client                |
