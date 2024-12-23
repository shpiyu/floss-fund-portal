# Try to get the commit hash from 1) git 2) the VERSION file 3) fallback.
LAST_COMMIT := $(or $(shell git rev-parse --short HEAD 2> /dev/null),$(shell head -n 1 VERSION | grep -oP -m 1 "^[a-z0-9]+$$"),"UNKNOWN")

# Try to get the semver from 1) git 2) the VERSION file 3) fallback.
VERSION := $(or $(shell git describe --tags --abbrev=0 2> /dev/null),$(shell grep -oP "tag: \K(.*)(?=,)" VERSION),"v0.0.0")

BUILDSTR := ${VERSION} (\#${LAST_COMMIT} $(shell date -u +"%Y-%m-%dT%H:%M:%S%z"))

GOPATH ?= $(HOME)/go
EASYJSON ?= $(GOPATH)/bin/easyjson
STUFFBIN ?= $(GOPATH)/bin/stuffbin

BIN := portal
STATIC := config.sample.toml schema.sql queries.sql

EASYJSON_MODELS := $\
	internal/models/models.go \
	internal/search/models.go

GENERATED_EASYJSON_MODELS := $\
	internal/models/models_easyjson.go \
	internal/search/models_easyjson.go

$(EASYJSON):
	go get github.com/zerodha/easyjson && go install github.com/zerodha/easyjson/...@latest

$(GENERATED_EASYJSON_MODELS): $(EASYJSON) $(EASYJSON_MODELS)
	$(EASYJSON) ${EASYJSON_MODELS}

$(STUFFBIN):
	go install github.com/knadh/stuffbin/...

$(BIN): $(shell find . -type f -name "*.go")
	CGO_ENABLED=0 go build -o ${BIN} -ldflags="-s -w -X 'main.buildString=${BUILDSTR}' -X 'main.versionString=${VERSION}'" cmd/${BIN}/*.go

.PHONY: generate
generate: $(GENERATED_EASYJSON_MODELS)

.PHONY: build
build: generate $(BIN)

.PHONY: run
run:
	CGO_ENABLED=0 go run -ldflags="-s -w -X 'main.buildString=${BUILDSTR}' -X 'main.versionString=${VERSION}'" cmd/${BIN}/*.go

# Run Go tests.
.PHONY: test
test:
	go test ./...

.PHONY: dist
dist: $(STUFFBIN) build pack-bin

# pack-releases runns stuffbin packing on the given binary. This is used
# in the .goreleaser post-build hook.
.PHONY: pack-bin
pack-bin: $(BIN) $(STUFFBIN)
	$(STUFFBIN) -a stuff -in ${BIN} -out ${BIN} ${STATIC}

# Use goreleaser to do a dry run producing local builds.
.PHONY: release-dry
release-dry:
	goreleaser --parallelism 1 --rm-dist --snapshot --skip-validate --skip-publish

# Use goreleaser to build production releases and publish them.
.PHONY: release
release:
	goreleaser --parallelism 1 --rm-dist --skip-validate
