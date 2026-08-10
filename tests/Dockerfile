FROM alpine:3.22

ARG CHEZMOI_VERSION=2.72.0
ARG TARGETARCH

RUN apk add --no-cache bash curl git grep jq python3 tar zsh \
    && curl -fsSL "https://github.com/twpayne/chezmoi/releases/download/v${CHEZMOI_VERSION}/chezmoi_${CHEZMOI_VERSION}_linux_${TARGETARCH}.tar.gz" \
      | tar -xz -C /usr/local/bin chezmoi

WORKDIR /src
ENTRYPOINT ["bash", "tests/test.sh"]
