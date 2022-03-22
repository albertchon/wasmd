# docker build . -t cosmwasm/wasmd:latest
# docker run --rm -it cosmwasm/wasmd:latest /bin/sh
FROM golang:1.17-alpine3.15 AS go-builder

# this comes from standard alpine nightly file
#  https://github.com/rust-lang/docker-rust-nightly/blob/master/alpine3.12/Dockerfile
# with some changes to support our toolchain, etc
RUN set -eux; apk add --no-cache ca-certificates build-base;

RUN apk add git
# NOTE: add these to run with LEDGER_ENABLED=true
# RUN apk add libusb-dev linux-headers

WORKDIR /code
COPY . /code/

# See https://github.com/CosmWasm/wasmvm/releases
ADD https://github.com/CosmWasm/wasmvm/releases/download/v1.0.0-beta8/libwasmvm_muslc.a /lib/libwasmvm_muslc.x86_64.a
ADD https://github.com/CosmWasm/wasmvm/releases/download/v1.0.0-beta8/libwasmvm_muslc.aarch64.a /lib/libwasmvm_muslc.aarch64.a
RUN sha256sum /lib/libwasmvm_muslc.x86_64.a | grep 903ab4715ba7c7586dfee9025a3c5bb17cd090329faa15ef91dcb01cc162bf1e
RUN sha256sum /lib/libwasmvm_muslc.aarch64.a | grep c6ad75bd3cd29115c714ec909ae080a0f1665d3407f11972c1a6d72b5cc48cc3
# Copy the library you want to the final location that will be used by the linker flag `-lwasmvm_muslc`
RUN cp /lib/libwasmvm_muslc.aarch64.a /lib/libwasmvm_muslc.a

# force it to use static lib (from above) not standard libgo_cosmwasm.so file
RUN LEDGER_ENABLED=false BUILD_TAGS=muslc make build

# --------------------------------------------------------
FROM alpine:3.15

COPY --from=go-builder /code/build/wasmd /usr/bin/wasmd

COPY docker/* /opt/
RUN chmod +x /opt/*.sh

WORKDIR /opt

# rest server
EXPOSE 1317
# tendermint p2p
EXPOSE 26656
# tendermint rpc
EXPOSE 26657

CMD ["/usr/bin/wasmd", "version"]