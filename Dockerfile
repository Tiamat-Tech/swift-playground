FROM node:lts-slim as node

WORKDIR /build

COPY package.json ./
RUN npm install

COPY webpack.*.js ./
COPY Public ./Public/
RUN npx webpack --config webpack.prod.js


FROM swift:5.4-focal as swift
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update && apt-get -q dist-upgrade -y \
    && apt-get install -y --no-install-recommends libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY --from=node /build /build
COPY ./Package.* ./
RUN swift package resolve

COPY . .
RUN swift build -c release

WORKDIR /staging
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/Run" ./ \
    && mv /build/Public ./Public && chmod -R a-w ./Public \
    && mv /build/Resources ./Resources && chmod -R a-w ./Resources


FROM swift:5.4-focal-slim
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update && apt-get -q dist-upgrade -y && rm -r /var/lib/apt/lists/*\
    && useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

WORKDIR /app
COPY --from=swift --chown=vapor:vapor /staging /app

USER vapor:vapor
EXPOSE 8080

ENTRYPOINT ["./Run"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
