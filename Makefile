GO ?= go
GOVERSION ?= go1.6
OS := $(shell uname | tr '[:upper:]' '[:lower:]')
SWAGGER ?= $(GOPATH)/bin/swagger

.DEFAULT_GOAL := all

goversion:
	@echo Checking go version...
	@( $(GO) version | grep -q $(GOVERSION) ) || ( echo "Please install $(GOVERSION) (found: $$($(GO) version))" && exit 1 )

all: check test bootstrap

check: goversion goimports govet

bootstrap: tether.linux tether.windows rpctool

apiservers: go-swagger dockerapi

goimports:
	@echo getting goimports...
	go get golang.org/x/tools/cmd/goimports
	@echo checking go imports...
	@! goimports -d $$(find . -type f -name '*.go' -not -path "./vendor/*") 2>&1 | egrep -v '^$$'

govet:
	@echo getting go vet...
	go get golang.org/x/tools/cmd/vet
	@echo checking go vet...
	@go tool vet -structtags=false -methods=false $$(find . -type f -name '*.go' -not -path "./vendor/*")

gvt:
	@echo getting gvt
	go get -u github.com/FiloSottile/gvt

vendor:
	@echo restoring vendor
	$(GOPATH)/bin/gvt restore

test:
	# test everything but vendor
	go test -v $(TEST_OPTS) github.com/vmware/vic/bootstrap/...
	go test -v $(TEST_OPTS) github.com/vmware/vic/imageC
	go test -v $(TEST_OPTS) github.com/vmware/vic/portlayer/...

tether.linux:
	@echo building tether-linux
	@CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GO) build -tags netgo -installsuffix netgo -o ./binary/tether-linux github.com/vmware/vic/bootstrap/tether/cmd/tether

tether.windows:
	@echo building tether-windows
	@CGO_ENABLED=0 GOOS=windows GOARCH=amd64 $(GO) build -tags netgo -installsuffix netgo -o ./binary/tether-windows github.com/vmware/vic/bootstrap/tether/cmd/tether

rpctool.linux:
	@echo building rpctool
	@GOARCH=amd64 GOOS=linux $(GO) build -o ./binary/rpctool --ldflags '-extldflags "-static"' github.com/vmware/vic/bootstrap/rpctool

rpctool: rpctool.linux

imageC: portlayerapi-client
	@echo building imageC...
	@CGO_ENABLED=0 $(GO) build -o ./binary/imageC --ldflags '-extldflags "-static"' github.com/vmware/vic/imageC

go-swagger:
	@echo Building the go-swagger generator...
	@$(GO) install ./vendor/github.com/go-swagger/go-swagger/cmd/swagger

dockerapi:
	@echo regenerating swagger models and operations for Docker API server...
	@$(SWAGGER) generate server -A docker -t ./apiservers/docker -f ./apiservers/docker/swagger.json

	@echo building Docker API server...
	@$(GO) build -o ./binary/docker-server ./apiservers/docker/cmd/docker-server

portlayerapi-client:
	@echo regenerating swagger models and operations for Portlayer API client...
	@$(SWAGGER) generate client -A PortLayer -t ./apiservers/portlayer -f ./apiservers/portlayer/swagger.yml

portlayerapi-server:
	@echo regenerating swagger models and operations for Portlayer API server...
	@$(SWAGGER) generate server -A PortLayer -t ./apiservers/portlayer -f ./apiservers/portlayer/swagger.yml

portlayerapi: portlayerapi-server
	@echo building Portlayer API server...
	@$(GO) build -o ./binary/port-layer-server ./apiservers/portlayer/cmd/port-layer-server/

clean:
	rm -rf ./binary

	@echo removing swagger generated files...
	rm -rf ./apiservers/docker/models
	rm -rf ./apiservers/docker/restapi/operations
	rm -f ./apiservers/docker/restapi/doc.go
	rm -f ./apiservers/docker/restapi/server.go
	rm -f ./apiservers/docker/restapi/embedded_spec.go

	rm -rf ./apiservers/portlayer/client/
	rm -rf ./apiservers/portlayer/cmd/
	rm -rf ./apiservers/portlayer/models/
	rm -rf ./apiservers/portlayer/restapi/doc.go
	rm -rf ./apiservers/portlayer/restapi/embedded_spec.go
	rm -rf ./apiservers/portlayer/restapi/operations/
	rm -rf ./apiservers/portlayer/restapi/server.go

.PHONY: test vendor imageC
