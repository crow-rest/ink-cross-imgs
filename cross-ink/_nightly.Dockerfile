# syntax=docker/dockerfile:1
ARG IMG_NAME=
ARG IMG_LABEL=
FROM $IMG_NAME:$IMG_LABEL

SHELL ["/bin/bash", "-c"]

RUN <<EOT
    set -euxo pipefail
    rustup toolchain uninstall stable
    rustup toolchain install nightly --allow-downgrade -c rustfmt,clippy,miri
EOT

SHELL ["/bin/sh", "-c"]

ENTRYPOINT [ "cargo", "+nightly" ]
CMD [ "auditable", "build" ]
