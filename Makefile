BINDIR=$(HOME)/bin
SCRIPTS_DIR=$(CURDIR)/shipyard/scripts/shared
export SCRIPTS_DIR

GOPROXY=https://proxy.golang.org
export GOPROXY

DAPPER_OUTPUT=$(CURDIR)/output
export DAPPER_OUTPUT

CLUSTERS_ARGS=--globalnet
DEPLOY_ARGS=--globalnet --deploytool_broker_args '--components service-discovery,connectivity'
SETTINGS=--settings $(CURDIR)/shipyard/.shipyard.e2e.yml

REPO=localhost:5000
IMAGE_VER=local
PRELOADS=lighthouse-agent lighthouse-coredns submariner-gateway submariner-globalnet submariner-route-agent submariner-networkplugin-syncer submariner-operator nettest

KIND_VERSION=v0.11.1
KUBECTL_VERSION=v1.22.4
HELM_VERSION=v3.4.1
YQ_VERSION=4.14.1
GOLANG_VERSION=1.17.3
ARCH=amd64

SUBMARINER_IO_GH = git@github.com:submariner-io
AXON_NET_GH = git@github.com:axon-net

all-images:	mod-replace mod-download build images

##@ Prepare

$(BINDIR):
	[ -x $(BINDIR) ] || mkdir -p $(BINDIR)

prereqs: $(BINDIR)	## Download required utilities
	@docker version --format 'Docker v{{.Server.Version}}' || (echo "Please install Docker Engine: https://docs.docker.com/engine/install" && exit 1)
	@go version || (echo "Installing golang" && rm -rf go && curl -L "https://go.dev/dl/go${GOLANG_VERSION}.linux-${ARCH}.tar.gz" | tar xzf - && mv go/bin/* $(BINDIR) && rm -rf go)
	[ -x $(BINDIR)/ ] || (curl -Lo $(BINDIR)/kind "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-${ARCH}" && chmod a+x $(BINDIR)/kind)
	[ -x $(BINDIR)/kind ] || (curl -Lo $(BINDIR)/kind "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-${ARCH}" && chmod a+x $(BINDIR)/kind)
	[ -x $(BINDIR)/kubectl ] || (curl -Lo $(BINDIR)/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && chmod a+x $(BINDIR)/kubectl)
	[ -x $(BINDIR)/yq ] || (curl -Lo $(BINDIR)/yq "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${ARCH}" && chmod a+x $(BINDIR)/yq)
	[ -x $(BINDIR)/helm ] || (curl -L "https://get.helm.sh/helm-$(HELM_VERSION)-linux-$(ARCH).tar.gz" | tar xzf - && mv linux-$(ARCH)/helm $(BINDIR) && rm -rf linux-$(ARCH))

git-clone-repos:	## Clone repositories from submariner-io
git-clone-repos:	clone-admiral clone-cloud-prepare clone-lighthouse clone-submariner
git-clone-repos:	clone-submariner-operator clone-shipyard

clone-%: %/.git
	@echo -n

.SECONDARY:
%/.git:
	git clone $(SUBMARINER_IO_GH)/$*.git
	@(cd $*; git remote rename origin submariner)
	@(cd $*; git remote add axon $(AXON_NET_GH)/$*.git)

#.PHONY: git-fetch-latest fetch-latest-admiral
git-fetch-latest:	## Fetch latest repositories from upstream
git-fetch-latest: fetch-latest-admiral fetch-latest-cloud-prepare fetch-latest-lighthouse
git-fetch-latest: fetch-latest-submariner fetch-latest-submariner-operator fetch-latest-shipyard

fetch-latest-%: clone-%
	@echo -- $@ --
	@(cd $*; git fetch submariner devel)

remove-git-repos:	## Remove local copy of upstream repositories
remove-git-repos: remove-admiral remove-cloud-prepare remove-lighthouse remove-submariner
remove-git-repos: remove-operator remove-shipyard

remove-%:
	@echo -- $@ --
	rm -rf $*

mod-replace:	## Update go.mod files with local replacements
	(cd admiral; go mod edit -replace=github.com/submariner-io/shipyard=../shipyard)
	(cd cloud-prepare; go mod edit -replace=github.com/submariner-io/admiral=../admiral)
	(cd lighthouse; go mod edit -replace=github.com/submariner-io/admiral=../admiral)
	(cd lighthouse; go mod edit -replace=github.com/submariner-io/shipyard=../shipyard)
	(cd submariner; go mod edit -replace=github.com/submariner-io/admiral=../admiral)
	(cd submariner; go mod edit -replace=github.com/submariner-io/shipyard=../shipyard)
	(cd submariner-operator; go mod edit -replace=github.com/submariner-io/admiral=../admiral)
	(cd submariner-operator; go mod edit -replace=github.com/submariner-io/shipyard=../shipyard)
	(cd submariner-operator; go mod edit -replace=github.com/submariner-io/cloud-prepare=../cloud-prepare)
	(cd submariner-operator; go mod edit -replace=github.com/submariner-io/lighthouse=../lighthouse)
	(cd submariner-operator; go mod edit -replace=github.com/submariner-io/submariner=../submariner)
	(cd submariner-operator; go mod edit -replace=github.com/submariner-io/submariner/pkg/apis=../submariner/pkg/apis)

mod-download:	## Download all module dependencies to go module cache
mod-download: mod-download-admiral mod-download-cloud-prepare mod-download-lighthouse
mod-download: mod-download-submariner mod-download-submariner-operator

mod-download-%:
	(cd $*; go mod download; go mod tidy)


##@ Build

build:	## Build all the binaries
build:	build-lighthouse build-submariner build-subctl build-operator

build-lighthouse:	## Build the lighthouse binaries
	(cd lighthouse; $(SCRIPTS_DIR)/compile.sh --noupx bin/lighthouse-agent pkg/agent/main.go)
	(cd lighthouse; $(SCRIPTS_DIR)/compile.sh --noupx bin/lighthouse-coredns pkg/coredns/main.go)

build-submariner:	## Build the submariner gateway binaries
	(cd submariner; $(SCRIPTS_DIR)/compile.sh --noupx bin/linux/amd64/submariner-gateway main.go)
	(cd submariner; $(SCRIPTS_DIR)/compile.sh --noupx bin/linux/amd64/submariner-globalnet pkg/globalnet/main.go)
	(cd submariner; $(SCRIPTS_DIR)/compile.sh --noupx bin/linux/amd64/submariner-route-agent pkg/routeagent_driver/main.go)
	(cd submariner; $(SCRIPTS_DIR)/compile.sh --noupx bin/linux/amd64/submariner-networkplugin-syncer pkg/networkplugin-syncer/main.go)

build-operator:		## Build the operator binaries
	(cd submariner-operator; $(SCRIPTS_DIR)/compile.sh --noupx bin/submariner-operator main.go)

build-subctl:	Makefile.subctl	## Build the subctl binary
	mkdir -p submariner-operator/build
	cd submariner-operator && $(MAKE) -f ../$< bin/subctl

images:	## Build all the images
images:	image-lighthouse image-submariner image-operator image-nettest

image-lighthouse:	## Build the lighthouse images
	(cd lighthouse; docker build -t $(REPO)/lighthouse-agent:$(IMAGE_VER) -f package/Dockerfile.lighthouse-agent .)
	(cd lighthouse; docker build -t $(REPO)/lighthouse-coredns:$(IMAGE_VER) -f package/Dockerfile.lighthouse-coredns .)

BUILD_ARGS=--build-arg TARGETPLATFORM=linux/amd64

image-submariner:	## Build the submariner gateway images
	(cd submariner; docker build -t $(REPO)/submariner-gateway:$(IMAGE_VER) -f package/Dockerfile.submariner-gateway $(BUILD_ARGS) .)
	(cd submariner; docker build -t $(REPO)/submariner-globalnet:$(IMAGE_VER) -f package/Dockerfile.submariner-globalnet $(BUILD_ARGS) .)
	(cd submariner; docker build -t $(REPO)/submariner-route-agent:$(IMAGE_VER) -f package/Dockerfile.submariner-route-agent $(BUILD_ARGS) .)
	(cd submariner; docker build -t $(REPO)/submariner-networkplugin-syncer:$(IMAGE_VER) -f package/Dockerfile.submariner-networkplugin-syncer $(BUILD_ARGS) .)

image-operator:		## Build the submariner operator image
	(cd submariner-operator; docker build -t $(REPO)/submariner-operator:$(IMAGE_VER) -f package/Dockerfile.submariner-operator .)

image-nettest:		## Build the submariner nettest image
	(cd shipyard; docker build -t $(REPO)/nettest:$(IMAGE_VER) -f package/Dockerfile.nettest .)

preload-images:		## Push images to development repository
	for repo in $(PRELOADS); do docker push $(REPO)/$$repo:$(IMAGE_VER); done

##@ Deployment

clusters:	## Create kind clusters that can be used for testing
	@mkdir -p $(DAPPER_OUTPUT)
	(cd submariner-operator; $(SCRIPTS_DIR)/clusters.sh $(CLUSTERS_ARGS) $(SETTINGS) )

	@echo Please run the following command to add kube contexts of the new clusters:
	@echo export KUBECONFIG=`ls -1p -d  output/kubeconfigs/* | xargs readlink -f | tr '\n' ':' | head -c -1`
	@echo .. and then to verify:
	@echo kubectl config get-contexts

deploy:	export DEV_VERSION=devel
deploy:	export CUTTING_EDGE=devel
deploy: export SUBCTL := $(CURDIR)/submariner-operator/bin/subctl
deploy: export PATH := $(CURDIR)/submariner-operator/bin:$(PATH)
deploy:		## Deploy submariner onto kind clusters
	./deploy.sh $(DEPLOY_ARGS) $(SETTINGS)

NAMESPACES ?= submariner-operator submariner-k8s-broker

undeploy:	## Clean submariner deployment from clusters
	-for k in output/kubeconfigs/*; do for n in $(NAMESPACES); do kubectl --kubeconfig $$k delete ns $$n; done; done

pod-status:	## Show status of pods in kind clusters
	for k in output/kubeconfigs/*; do kubectl --kubeconfig $$k get pod -A; done

##@ General

shell:
	$(SHELL)

clean:	## Clean up the built artifacts
	rm -f lighthouse/bin/lighthouse-agent
	rm -f lighthouse/bin/lighthouse-coredns
	rm -f submariner/bin/linux/amd64/submariner-gateway
	rm -f submariner/bin/linux/amd64/submariner-globalnet
	rm -f submariner/bin/linux/amd64/submariner-route-agent
	rm -f submariner/bin/linux/amd64/submariner-networkplugin-syncer
	rm -f submariner-operator/bin/submariner-operator
	rm -f submariner-operator/bin/subctl*
	rm -rf submariner-operator/deploy/crds
	rm -rf submariner-operator/deploy/submariner
	rm -f submariner-operator/pkg/subctl/operator/common/embeddedyamls/yamls.go

stop-clusters:	## Removes the running kind clusters
	-for c in `kind get clusters`; do kind delete cluster --name $$c; done
	-rm -f output/kubeconfigs/*

stop-all:	## Removes the running kind clusters and kind-registry
	(cd submariner-operator; $(SCRIPTS_DIR)/cleanup.sh)


help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; \
		printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} \
		/^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: help
.DEFAULT_GOAL := help
