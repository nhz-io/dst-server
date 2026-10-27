# Don't Starve Together dedicated server.
#
# The game directory is fetched in CI by DepotDownloader (SteamRE), NOT by
# steamcmd — anonymous `steamcmd +app_update 343050` fails with "Missing
# configuration" since Steam stopped issuing manifest request codes to
# anonymous steamcmd sessions. DepotDownloader negotiates them correctly.
#
# Paths deliberately mirror superjump22/dontstarvetogether (the image this
# replaces), so the consuming Deployment only changes its `image:` line:
#   game dir    /home/steam/dst/game
#   entrypoint  bin64/dontstarve_dedicated_server_nullrenderer_x64
# Saves/config/mods are mounted by the consumer via -persistent_storage_root.
FROM debian:12-slim

# libcurl-gnutls.so.4 is the one runtime library the x64 server binary links
# beyond libc. No 32-bit anything: only bin64 is shipped.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libcurl3-gnutls ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -u 1000 -m steam

ARG DST_VERSION=unknown
ENV DST_VERSION=${DST_VERSION}
LABEL org.opencontainers.image.source="https://github.com/nhz-io/dst-server"
LABEL dst.version="${DST_VERSION}"

# The game tree arrives pre-split into ten size-balanced buckets (see the
# workflow's bin-pack step). One COPY per bucket = one moderate blob per
# layer instead of a single ~3 GB blob — long single-blob transfers from
# ghcr's CDN were observed dying with `tls: bad record MAC` on the consuming
# LAN, and small blobs pass the same path untouched. Buckets always exist
# (CI creates all ten, empty ones included), and they merge in overlayfs.
COPY --chown=steam:steam parts/part0/ /home/steam/dst/game/
COPY --chown=steam:steam parts/part1/ /home/steam/dst/game/
COPY --chown=steam:steam parts/part2/ /home/steam/dst/game/
COPY --chown=steam:steam parts/part3/ /home/steam/dst/game/
COPY --chown=steam:steam parts/part4/ /home/steam/dst/game/
COPY --chown=steam:steam parts/part5/ /home/steam/dst/game/
COPY --chown=steam:steam parts/part6/ /home/steam/dst/game/
COPY --chown=steam:steam parts/part7/ /home/steam/dst/game/
COPY --chown=steam:steam parts/part8/ /home/steam/dst/game/
COPY --chown=steam:steam parts/part9/ /home/steam/dst/game/

USER steam
WORKDIR /home/steam/dst/game/bin64
RUN chmod +x dontstarve_dedicated_server_nullrenderer_x64 || true
ENTRYPOINT ["./dontstarve_dedicated_server_nullrenderer_x64"]
