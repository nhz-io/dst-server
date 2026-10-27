# dst-server

Don't Starve Together dedicated server image for the shinsenkyo cluster,
built directly from Klei's Steam releases — no third-party image in the chain.

- **Why not steamcmd**: anonymous `+app_update 343050` fails with
  "Missing configuration" (Steam no longer issues manifest request codes to
  anonymous steamcmd). [DepotDownloader](https://github.com/SteamRE/DepotDownloader)
  negotiates them correctly and needs no account.
- **Schedule**: every 30 minutes the workflow downloads only `version.txt`
  (7 bytes) from the Linux depot and compares against published ghcr tags.
  A new version triggers the full 4.3 GB fetch, build, and push of
  `ghcr.io/nhz-io/dst-server:<version>` + `:latest`.
- **Layout** mirrors the image it replaced (`superjump22/dontstarvetogether`):
  game at `/home/steam/dst/game`, entrypoint `bin64/dontstarve_dedicated_server_nullrenderer_x64`,
  runs as uid 1000. One container = one shard; the consumer passes
  `-shard Master` / `-shard Caves`.

Consumer: `manifests/dst.yaml` in talos-local-cluster.
