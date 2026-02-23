# Docker Registry(v2) Manifest Cleanup
## Update note
<aside class="warning">
Some variable names have changed, please check the documentation below if your script stopped working.
</aside>

## About
This script will search your registry and delete all manifests that do not have any tags associated. Deletion happens through the docker-registry API and should, therefore, be reasonably safe. After running this, you should do a garbage collect in the registry to free up the disk space.

### Why does this happen?
Docker images can be pulled both via `image:tag` and via `image@digest`. Because of this, if you overwrite an `image:tag` with a different one (e.g., pushing nightly to `whateverimage:latest`) you will still be able to pull the OLD versions of that tag by using `image@digest`. This functionality means the registry garbage collect cannot remove an image because a reference still exists.

### Isn't this a bug?
Not really, some people use `image@digest` to make sure they pull the correct image to be certain that they get the right code in their project. Docker DAB files are one example of this.

There is; however, some work being done to make an API endpoint to find these 'hidden' manifests quickly. This work is being done in [docker/distribution#2170](https://github.com/docker/distribution/issues/2170) and [docker/distribution#2169](https://github.com/docker/distribution/pull/2169).

A feature request to be able to explicitly garbage collect untagged manifests is proposed in [docker/distribution#1844](https://github.com/docker/distribution/issues/1844). 

This repo is meant as a workaround until we have the necessary tooling in Docker and registry to handle this without 3rd party tools.

## Usage
### Running against local storage
See the *examples* below if needed. Deletion needs to be enabled in your registry. See [the Docker documentation](https://docs.docker.com/registry/configuration/#delete)

After running this, you should do a garbage collect in the registry to free up the disk space.

| Variable name | Required | Description | Example |
| --- | --- | --- | --- |
| REGISTRY_URL | Yes | The URL to the registry | `http://example.com:5000/` |
| REGISTRY_DIR | No | The path to the registry dir - not needed if using the docker container and mounting in the dir in /registry (see examples) | `/registry` |
| SELF_SIGNED_CERT | No | Set this if using a self-signed cert | `true` |
| REGISTRY_AUTH | No | Set this when using http basic auth | `username:password` |
| DRY_RUN | No | Set this to do a dry-run (e.g. don't delete anything, just show what would be done) | `true` |
| REPO_FILTER | No | Restrict cleanup to a single named repository | `myapp` |
| HASH_TAG_PATTERN | No | Regex to identify commit-hash tags for age-based cleanup (default: `^[0-9a-f]{7,12}$`) | `^[0-9a-f]{8}$` |
| HASH_TAG_KEEP | No | Number of most recent hash-tagged images to keep per repository (default: `10`) | `5` |

#### Examples of running against local storage:
Simplest way:
```
docker run -it -v /home/someuser/registry:/registry -e REGISTRY_URL=http://192.168.77.88:5000 cygnusnetworks/docker-registry-manifest-cleanup
```

To test it without changing anything in your registry:
```
docker run -it -v /home/someuser/registry:/registry -e REGISTRY_URL=http://192.168.77.88:5000 -e DRY_RUN="true" cygnusnetworks/docker-registry-manifest-cleanup
```

With more options:
```
docker run -it -v /home/someuser/registry:/registry -e REGISTRY_URL=http://192.168.77.88:5000 -e SELF_SIGNED_CERT="true" -e REGISTRY_AUTH="myuser:sickpassword" cygnusnetworks/docker-registry-manifest-cleanup
```

Restrict to a single repository:
```
docker run -it -v /home/someuser/registry:/registry -e REGISTRY_URL=http://192.168.77.88:5000 -e REGISTRY_AUTH="myuser:sickpassword" -e REPO_FILTER="myapp" -e DRY_RUN="true" cygnusnetworks/docker-registry-manifest-cleanup
```

### Commit-hash tag cleanup

CI/CD pipelines often tag images with short git commit hashes (e.g. `myapp:3f33a785`). These accumulate over time and consume significant disk space. The script can automatically delete old hash-tagged images while keeping the N most recent ones per repository.

Tags matching `HASH_TAG_PATTERN` are sorted by image creation date. The `HASH_TAG_KEEP` most recent are kept; the rest are deleted. A manifest is never deleted if it also carries a non-hash tag (e.g. `latest`, `3.16`).

```
docker run -it -v /home/someuser/registry:/registry \
  -e REGISTRY_URL=http://192.168.77.88:5000 \
  -e REGISTRY_AUTH="myuser:sickpassword" \
  -e HASH_TAG_KEEP=5 \
  -e DRY_RUN="true" \
  cygnusnetworks/docker-registry-manifest-cleanup
```

### Output format

Before performing any deletions the script prints a summary of what is in the registry:

```
Version-tagged manifests (always kept):
  [keep] sha256:f7da6fb39403  repo=myapp   tag=3.16    created=2026-02-17 10:23:39  index [linux/amd64, linux/arm64]
  [keep] sha256:f7da6fb39403  repo=myapp   tag=latest  created=2026-02-17 10:23:39  index [linux/amd64, linux/arm64]

Hash-tagged manifests (keeping 10 most recent per repo):
  [keep] sha256:cf4b05e83109  repo=myapp   tag=3f33a785  created=2025-12-01 08:15:44  linux/amd64

Hash-tagged manifests to delete (beyond 10 most recent per repo):
  DRY_RUN: sha256:2e8f2a8622a3  repo=myapp   created=2023-04-03 11:24:28  linux/amd64

Untagged manifests to delete (94 in registry):
  Cleaning 1 of 94 ..not really, due to dry-run mode
  DRY_RUN: sha256:5fa55b3f875e  repo=myapp   created=2023-09-12 10:05:33  linux/amd64
```

### Running against S3 storage
See the *examples* below if needed.

After running this, you should do a garbage collect in the registry to free up the disk space.

| Variable name | Required | Description | Example | 
| --- | --- | --- | --- |
REGISTRY_STORAGE | Yes | Tells the script to run against S3 | `S3` | 
REGISTRY_URL | Yes | The URL to the registry | `http://example.com:5000/` | 
ACCESS_KEY | Yes | The Accesskey to S3 | `XXXXXXGZMXXXXQMAGXXX` |
SECRET_KEY | Yes | The secret to S3 | `zfXXXXXEbq/JX++XXXAa/Z+ZCXXXXypfOXXXXC/X` |
BUCKET | Yes | The name of the bucket | `registry-bucket-1` |
REGION | Yes | The region in which the bucket is located | `eu-central-1` | 
REGISTRY_DIR | No | Only needed if registry is not in the root folder of the bucket | `/path/to/registry` |
SELF_SIGNED_CERT | No | Set this if using a self-signed cert | `true` |
REGISTRY_AUTH | No | Set this when using http basic auth | `username:password` |
DRY_RUN | No | Set this to do a dry-run (e.g. don't delete anything, just show what would be done) | `true` | 

#### Examples of running against S3 storage
Simplest way:
```
docker run -it -e REGISTRY_URL=http://192.168.77.88:5000 -e REGISTRY_STORAGE="S3" -e ACCESS_KEY="XXXXXXGZMXXXXQMAGXXX" -e SECRET_KEY="zfXXXXXEbq/JX++XXXAa/Z+ZCXXXXypfOXXXXC/X" -e BUCKET="registry-bucket-1" -e REGION="eu-central-1" cygnusnetworks/docker-registry-manifest-cleanup
```

To test it without changing anything in your registry:
```
docker run -it -e DRY_RUN="true" -e REGISTRY_URL=http://192.168.77.88:5000 -e REGISTRY_STORAGE="S3" -e ACCESS_KEY="XXXXXXGZMXXXXQMAGXXX" -e SECRET_KEY="zfXXXXXEbq/JX++XXXAa/Z+ZCXXXXypfOXXXXC/X" -e BUCKET="registry-bucket-1" -e REGION="eu-central-1" cygnusnetworks/docker-registry-manifest-cleanup
```

With more options:
```
docker run -it -e REGISTRY_URL=http://192.168.77.88:5000 -e REGISTRY_STORAGE="S3" -e ACCESS_KEY="XXXXXXGZMXXXXQMAGXXX" -e SECRET_KEY="zfXXXXXEbq/JX++XXXAa/Z+ZCXXXXypfOXXXXC/X" -e BUCKET="registry-bucket-1" -e REGION="eu-central-1" -e SELF_SIGNED_CERT="true" -e REGISTRY_AUTH="myuser:sickpassword" cygnusnetworks/docker-registry-manifest-cleanup
```

### Running against Harbor and other baerer token-based authentication forms
The run should be the same, the only requirement is that the `user:pass` you provide should have full access to all repositories (and/or projects), since it needs to be able to delete manifests whereever its needed.

When running against Harbor, use a user that's in all projects as a project admin. When the run is finished, you can run the garbage collection through the Harbor UI.

This has been tested working in Harbor 1.7.0.

## License
This project is distributed under [Apache License, Version 2.0.](LICENSE)

Copyright © 2018 Morten Steen Rasmussen
