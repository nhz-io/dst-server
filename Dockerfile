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
FROM debian:trixie-slim

# The Steam runtime, reproduced from cm2network/steamcmd (superjump22's base):
# 32-bit libs, steamcmd self-updated once, and Steam's REAL steamclient.so
# linked into ~/.steam/sdk32|sdk64 and /usr/lib. steamcmd is never used to
# fetch the game (see above) — it is here only for the client libraries.
#
# ⚠️ NOT OPTIONAL. The first version of this image shipped only the
# steamclient.so bundled with the game, and every returning player spawned
# NAKED with a blank map: the server derives each player's save folder from
# their id, and without this runtime it derived a raw `OU_<id>_` folder
# instead of the hashed `C7GS…` one the existing saves use — same build,
# same args, same save (2026-10-27). Any change here: verify a test join logs
# `Resuming user: session/<id>/C7GS…` BEFORE players return.
ENV USER=steam HOMEDIR=/home/steam STEAMCMDDIR=/home/steam/steamcmd
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        lib32stdc++6 lib32gcc-s1 ca-certificates curl locales \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && useradd -u 1000 -m "${USER}" \
    && su "${USER}" -c \
        "mkdir -p \"${STEAMCMDDIR}\" \
         && curl -fsSL 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz' | tar xzf - -C \"${STEAMCMDDIR}\" \
         && \"${STEAMCMDDIR}/steamcmd.sh\" +quit \
         && ln -s \"${STEAMCMDDIR}/linux32/steamclient.so\" \"${STEAMCMDDIR}/steamservice.so\" \
         && mkdir -p \"${HOMEDIR}/.steam/sdk32\" \"${HOMEDIR}/.steam/sdk64\" \
         && ln -s \"${STEAMCMDDIR}/linux32/steamclient.so\" \"${HOMEDIR}/.steam/sdk32/steamclient.so\" \
         && ln -s \"${STEAMCMDDIR}/linux32/steamcmd\" \"${STEAMCMDDIR}/linux32/steam\" \
         && ln -s \"${STEAMCMDDIR}/linux64/steamclient.so\" \"${HOMEDIR}/.steam/sdk64/steamclient.so\" \
         && ln -s \"${STEAMCMDDIR}/linux64/steamcmd\" \"${STEAMCMDDIR}/linux64/steam\" \
         && ln -s \"${STEAMCMDDIR}/steamcmd.sh\" \"${STEAMCMDDIR}/steam.sh\"" \
    && ln -s "${STEAMCMDDIR}/linux64/steamclient.so" /usr/lib/x86_64-linux-gnu/steamclient.so \
    && test -f "${HOMEDIR}/.steam/sdk64/steamclient.so" \
    && rm -rf /var/lib/apt/lists/*

# What superjump22 adds on top of that base, verbatim in effect.
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends libcurl4-gnutls-dev:i386 libcurl3-gnutls \
    && rm -rf /var/lib/apt/lists/*
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 STEAM_APPID=343050 DST_DIR=/home/steam/dst \
    DST_GAMEDIR=/home/steam/dst/game DST_SAVEDIR=/home/steam/dst/save

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
