# The official `gcc` image is Debian-only — no `-alpine` tag exists.
# Use alpine + build-base so the build stage and the runtime stage share
# the same musl libc (otherwise the binary copy-out would crash on link).
FROM alpine:3.19 AS build
RUN apk add --no-cache build-base git make
WORKDIR /src
RUN git clone --depth 1 https://github.com/electrum/tpch-dbgen.git . \
    && cp makefile.suite Makefile \
    && sed -i 's/^CC.*/CC = gcc/' Makefile \
    && sed -i 's/^DATABASE.*/DATABASE = ORACLE/' Makefile \
    && sed -i 's/^MACHINE.*/MACHINE = LINUX/' Makefile \
    && sed -i 's/^WORKLOAD.*/WORKLOAD = TPCH/' Makefile \
    && make

FROM alpine:3.19
RUN apk add --no-cache libstdc++ postgresql16-client bash
COPY --from=build /src/dbgen     /usr/local/bin/
COPY --from=build /src/dists.dss /opt/tpch/
WORKDIR /data
ENV DSS_PATH=/data DSS_CONFIG=/opt/tpch
COPY seed/load.sh /usr/local/bin/load.sh
RUN chmod +x /usr/local/bin/load.sh
ENTRYPOINT ["/usr/local/bin/load.sh"]
