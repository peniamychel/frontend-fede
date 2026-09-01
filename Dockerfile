# syntax=docker/dockerfile:1.7

# La imagen comunitaria de Flutter disponible en el registro trae un Dart más
# antiguo que el proyecto. Construimos sobre Debian con el SDK oficial exacto
# para que coincida con desarrollo y no dependa de una etiqueta mutable.
FROM debian:bookworm-slim AS compilacion

ARG FLUTTER_VERSION=3.47.1
ENV FLUTTER_HOME=/opt/flutter
ENV PUB_CACHE=/home/constructor/.pub-cache
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl git unzip xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 1000 constructor \
    && curl --fail --location --retry 3 \
       "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
       --output /tmp/flutter.tar.xz \
    && tar --extract --xz --file /tmp/flutter.tar.xz --directory /opt \
    && rm /tmp/flutter.tar.xz \
    && mkdir -p /workspace \
    && chown -R constructor:constructor /opt/flutter /home/constructor /workspace

USER constructor
RUN git config --global --add safe.directory /opt/flutter \
    && flutter config --enable-web \
    && flutter precache --web

WORKDIR /workspace

COPY --chown=constructor:constructor pubspec.yaml pubspec.lock ./
RUN --mount=type=cache,target=/home/constructor/.pub-cache,uid=1000,gid=1000 \
    flutter pub get

COPY --chown=constructor:constructor . .
RUN --mount=type=cache,target=/home/constructor/.pub-cache,uid=1000,gid=1000 \
    flutter build web --release --no-web-resources-cdn

FROM nginx:1.29-alpine AS ejecucion
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=compilacion /workspace/build/web /usr/share/nginx/html

EXPOSE 80
