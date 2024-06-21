# downloader

## Usage

```sh
url=...
docker run --rm --init --user "$(id -u)":"$(id -g)" --volume "$(pwd)":/checkout --workdir /checkout ghcr.io/taiki-e/downloader aria2c "$url"
```

As a stage of [multi-stage build][multi-stage-build]. (The original purpose of this image.)

```dockerfile
FROM ghcr.io/taiki-e/downloader AS downloader
ARG URL=...
RUN wget "$URL"

FROM ubuntu
COPY --from=downloader ... ...
```

[multi-stage-build]: https://docs.docker.com/develop/develop-images/multistage-build
