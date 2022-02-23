# submariner-project

```sh
Usage:
  make <target>

Prepare
  prereqs             Download required utilities
  git-clone-repos     Clone repositories from submariner-io
  git-fetch-latest    Fetch latest repositories from upstream, does *not* rebase
  git-stable          Update repositories to last set tag
  mod-replace         Update go.mod files with local replacements
  mod-download        Download all module dependencies to go module cache

Build
  build               Build all the binaries
  build-lighthouse    Build the lighthouse binaries
  build-submariner    Build the submariner gateway binaries
  build-operator      Build the operator binaries
  build-subctl        Build the subctl binary
  images              Build all the images
  image-lighthouse    Build the lighthouse images
  image-submariner    Build the submariner gateway images
  image-operator      Build the submariner operator image
  image-nettest       Build the submariner nettest image

Deployment
  preload-images      Push images to development repository
  clusters            Create kind clusters that can be used for testing
  deploy              Deploy submariner onto kind clusters
  pod-status          Show status of pods in kind clusters

Cleanup
  clean               Clean up the built artifacts in all sub-repos
  remove-git-repos    Remove local copy of upstream repositories
  undeploy            remove submariner resources from all kind clusters
  remove-clusters     Removes the running kind clusters
  stop-all            Removes the running kind clusters and kind-registry

General
  help                Display this help.
```

## First Time Usage

Order of `make` commands:

```sh
make prereqs
make git-clone-repos
make mod-replace
make mod-download
make build
make images
make clusters
make preload-images
make deploy
```

## Iterative Development

Once you have submariner deployed, you can iteratively develop a single component. For example,
lighthouse can be rebuilt like this:

```
make build-lighthouse image-lighthouse preload-images
```

You can then kill the lighthouse-agent pod in a cluster and it will automatically redeploy with
the new image. This works because the images have version `local` and `imagePullPolicy: Always`.

If you want to run e.g. lighthouse-agent outside the cluster, then you need to scale both
submariner-operator and lighthouse-agent down to zero, i.e. `replicas: 0`.
