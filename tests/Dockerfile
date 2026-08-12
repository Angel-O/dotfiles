FROM alpine:3.22

ARG CHEZMOI_VERSION=2.72.0
ARG TARGETARCH

RUN apk add --no-cache bash curl git grep jq python3 tar zsh \
    && if [ "$TARGETARCH" = amd64 ]; then archive_arch=linux-musl_amd64; else archive_arch="linux_${TARGETARCH}"; fi \
    && curl -fsSL "https://github.com/twpayne/chezmoi/releases/download/v${CHEZMOI_VERSION}/chezmoi_${CHEZMOI_VERSION}_${archive_arch}.tar.gz" \
       | tar -xz -C /usr/local/bin chezmoi

WORKDIR /src
ENTRYPOINT ["bash", "tests/test.sh"]
