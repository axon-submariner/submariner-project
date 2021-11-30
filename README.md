# submariner-project

```
Usage:
  make <target>

Prepare
  git-init          Initialise submodules
  prereqs           Download required utilities
  mod-replace       Update go.mod files with local replacements
  mod-download      Download all module dependencies to go module cache

Build
  build             Build all the binaries
  build-lighthouse  Build the lighthouse binaries
  build-submariner  Build the submariner gateway binaries
  build-operator    Build the operator binaries
  build-subctl      Build the subctl binary
  images            Build all the images
  image-lighthouse  Build the lighthouse images
  image-submariner  Build the submariner gateway images
  image-operator    Build the submariner operator image
  preload-images    Push images to development repository

Deployment
  clusters          Create kind clusters that can be used for testing
  deploy            Deploy submariner onto kind clusters
  undeploy          Clean submariner deployment from clusters
  pod-status        Show status of pods in kind clusters

General
  clean             Clean up the built artifacts
  clean-clusters    Removes the running kind clusters
  help              Display this help.
```

Order of `make` commands:

```
make git-init
make prereqs
make mod-replace
make mod-download
make build
make images
make clusters
make preload-images
make deploy
```

