### Install Runner

Create dokku app

```csharp
dokku apps:create gitea-runner
mkdir /var/lib/dokku/data/storage/gitea-runner/conf
mkdir /var/lib/dokku/data/storage/gitea-runner/data
mkdir /var/lib/dokku/data/storage/gitea-runner/ssh
dokku storage:ensure-directory gitea-runner /var/lib/dokku/data/storage/gitea-runner
dokku storage:mount gitea-runner /var/lib/dokku/data/storage/gitea-runner/conf/:/conf/
dokku storage:mount gitea-runner /var/lib/dokku/data/storage/gitea-runner/data/:/data/
dokku storage:mount gitea-runner /var/run/docker.sock:/var/run/docker.sock
# NEED TO ADD GITEA_RUNNER_REGISTRATION_TOKEN and config yml location
dokku config:set gitea-runner GITEA_RUNNER_REGISTRATION_TOKEN=...
dokku config:set gitea-runner GITEA_INSTANCE_URL=...
dokku config:set gitea-runner CONFIG_FILE_PATH="/conf/config.yaml"
dokku config:set gitea-runner GITEA_RUNNER_JOB_CONTAINER_DOCKER_HOST=unix:///var/run/docker.sock

```

This repo is start Point, but this is for Docker so i am was need to make some changes.

[act_runner](https://gitea.com/gitea/act_runner)

So my working repo is, actualy my repo just make conf.yml on ferst run. This only one change.
https://github.com/dufok/dokku-act-runner

And, runner will be starting our Deploy. So, it is need ssh key for that registered in dokku.

```csharp
# Generate ssh key for Runner
ssh-keygen -t rsa -C "admin@daruma.dev" -f /var/lib/dokku/data/storage/
gitea-runner/ssh/id_rsa
```

Or you can add you SSH key, if you prefer. In repository settings → runners → secrets:

```csharp
SSH_PRIVATE_KEY=...
```

If repository is in Organization, then secret for actions can be added in Organization. This is will working on all repositories inside.

And in Gitea need to check “**Enable repository Actions**” in repository settings.

In the Repo:

Repository need rules to be runneble with actions:

- .gitea/workflows/main.yml
    
    ```csharp
    name: 'deploy'
    on: [push]
    
    jobs:
      deploy:
        runs-on: ubuntu-latest
        steps:
          - name: Cloning repo
            uses: actions/checkout@v2
            with:
              fetch-depth: 0
    
          - name: Get Repo Name
            id: repo_name
            run: echo "::set-output name=repo::$(echo ${GITHUB_REPOSITORY##*/})"
    
          - name: Push to dokku
            uses: dokku/github-action@master
            with:
              branch: 'main'
              git_remote_url: 'ssh://dokku@staging.discours.io:22/${{ steps.repo_name.outputs.repo }}'
              ssh_private_key: ${{ secrets.SSH_PRIVATE_KEY }}
    ```