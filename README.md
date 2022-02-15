# submariner-project

```sh
Usage:
  make <target>

Prepare
  prereqs          Download required utilities
  git-clone-repos  Clone repositories from submariner-io
  git-fetch-latest Fetch latest repositories from upstream, does *not* rebase
  remove-git-repos Remove local copy of upstream repositories
  mod-replace      Update go.mod files with local replacements
  mod-download     Download all module dependencies to go module cache

Build
  build            Build all the binaries
  build-lighthouse Build the lighthouse binaries
  build-submariner Build the submariner gateway binaries
  build-operator   Build the operator binaries
  build-subctl     Build the subctl binary
  images           Build all the images
  image-lighthouse Build the lighthouse images
  image-submariner Build the submariner gateway images
  image-operator   Build the submariner operator image
  image-nettest    Build the submariner nettest image
  preload-images   Push images to development repository

Deployment
  clusters         Create kind clusters that can be used for testing
  deploy           Deploy submariner onto kind clusters
  undeploy         Clean submariner deployment from clusters
  pod-status       Show status of pods in kind clusters

General
  clean            Clean up the built artifacts
  stop-clusters    Removes the running kind clusters
  stop-all         Removes the running kind clusters and kind-registry
  help             Display this help.
```

Order of `make` commands:

```sh
make prereqs
make git-fetch-latest # will clone if needed
make mod-replace
make mod-download
make build
make images
make clusters
make preload-images
make deploy
```

## Inner development loop (e.g., for lighthouse)

```sh
cd lighthouse 
# make changes to code...
cd ..
make images
make preload-images
# kill relevant Pods in cluster and validate they restart with the new image
# (imagePullPolicy should be set to Always)
# Can also build and run out of cluster by first scaling submariner-operator to 
# zero replicas so it does not attempt to restart killed components in-cluster
```
