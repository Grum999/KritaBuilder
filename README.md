# Krita Builder

This tool is based on [Dmitry Kazakov Krita build docker](https://invent.kde.org/dkazakov/krita-docker-env.git), itself based on the official [KDE build environment](https://binary-factory.kde.org/job/Krita_Nightly_Appimage_Dependency_Build/) that in used on KDE CI for building official AppImage packages.

## Prerequisites

First, ensure you have *Docker* and *git* installed.

> Installation on a Debian
> ```bash
> sudo apt install git docker docker.io
> ```

Eventually, change docker settings `/etc/docker/daemon.json` to define where dockers are stored.
```json
{
    "data-root" : "/home/xxxx/docker"
}
```


## Installation

To install **Krita Builder**, you just need to clone repository:
```bash
git clone https://github.com/Grum999/KritaBuilder.git
```

Once repository is cloned, you can check script:
```bash
./kbuilder
```

Then you should have something like this:
```
Usage: kbuilder [COMMAND] [OPTIONS]

  Manage Krita build environments

  Available commands:
    new                             Create a new build environment
    remove                          Remove a build environment
    rename                          Rename a build environment
    list                            List build environments
    start                           Start a build environment
    stop                            Stop a running build environment
    build                           Build Krita from environment
    krita                           Execute Krita from environment
    logs                            Get last build logs
    tool                            Execute Docker tool

  Available options:
    -h,         --help              Display help
    -v,         --version           Display version
```

You can get help on all commands.
> Get help for command **new**
> ```bash
> ./kbuilder new --help
> ```

## Create a build environment

**Krita Builder** allows you to manage different build environments.

By default, when creating a new environment, official [*Krita* repository](https://invent.kde.org/graphics/krita) is cloned.
```bash
./kbuilder new my_build_environment
```

If you want to use an alternative local repository, you can provide provide its location with `--source-path` option.

Execution of Krita in the container do not let the ability the access to host file system (you can't access your home directory).
Also, any file saved within the container is lost when container is stopped.

You may want a place where you can read and write documents from the container and from your computer, without loosing these documents when container is stopped: use option `--data-path` for that.

> Example:
> - Use local repository located in `/home/xxxx/Sources/krita`
> - Use local data located in `/home/xxxx/temp_data` (will be available in `~/data` within docker)
> ```bash
> ./kbuilder new --source-path=/home/xxxx/Sources/krita --data-path/home/xxxx/temp_data --verbose my_build_environment
> ```

When an environment is created, automatically:
- Dependencies will be downloaded and built
- Krita will be built

According to your internet connection and computer specifications, this can take a very long time...

Also please note an environment requires about ~35GB of available space to build Krita.


## Manage environments

Each environment is a *Docker*.

All files (source code, binaries, ...) are NOT stored in the docker but in **Krita Builder** `environements` directory.

| Directory | Description |
| --- | --- |
| `.docker-config` | Is the `~/.config` directory of your docker<br>It allows to keep persistent data setup even if Docker is stopped |
| `appimages` | Is the place where appimages are built |
| `data` | Is the `~/data` directory of your docker<br>It allows you to access to persistent data from/to the docker (get access from your computer to `.kra` files saved in `~/data` for example) |
| `sources` | Is the place where *Krita* repository will be cloned (if not provided) and dependencies sources will be downloaded |
| `workspaces` |Is the place where *Krita* build files will be produced |

### Start and Stop environments

The command **`start`** will start docker for designed build environment, the **stop** command will stop the docker.

> Example:
> ```bash
> ./kbuilder start my_build_environment
> ./kbuilder stop my_build_environment
> ```

> Note: any command that need a *running* docker will automatically start docker if needed.

### List environments

The command **`list`** will provide a list of available environments, and according to options the status and some informations about usage.

> Example:
> Get list of environments, with their size and data source location
> ```bash
> ./kbuilder list --size --source-uri
> ```


### Rename environments

The command **`rename`** will let you rename an environment if initial defined name need to be changed.

> Example:
> ```bash
> ./kbuilder rename my_build_environment my_new_name
> ```


### Remove environments

The command **`remove`** will delete everything related to an environment:
- Directories
- Docker

> Example:
> ```bash
> ./kbuilder remove my_new_name
> ```

> Note: if a specific *Krita* local repository has been provided (instead of working with and automatic clone), the specific local repository is not removed!

## Build Krita

The command **build** will start a new Krita's build from defined source repository.

- Use `--appimage` option to create an appimage
- Use `--clean` option to rebuild *Krita* without using cached files
- Use `--clean-sip` option if you're working in Krita's Python API, and especially if you've modified `.sip` files
- Use `--deps` option to force rebuild of dependencies (the `--clean` will be automatically be applied)
- Use `--run` option to execute *Krita* immediately after build; if build is in failure, option will be ignored

> Example:
> Clean make cache and build Krita
> ```bash
> ./kbuilder build --verbose --clean my_build_environment
> ```
>
> Clean make cache, rebuild dependencies, create appimage and run Krita once build is finished
> ```bash
> ./kbuilder build --verbose --deps --appimage --run my_build_environment
> ```


## Running Krita

The command **`krita`** will execute *Krita* from last built binaries.

Execution is made from the docker.

- Use `--appimage` option to execute last *Krita* appimage built (will not be executed from docker, but directly from your session)
- Use `--scale` option to change `QT_SCALE_FACTOR` value
- Use `--debug` option to execute *Krita* with *gdb*, *valgrind* or *callgrind*

> Example:
> Execute Krita
> ```bash
> ./kbuilder krita
> ```
>
> Execute Krita with gdb
> ```bash
> ./kbuilder krita --debug=gdb
> ```

## Check logs

The command **`logs`** let you the ability to show logs produced from the last build execution.

- Use `--full` option to get complete logs
- Use `--debug` option to get debug logs *if Krita has been executed with `--debug` option*

## Tools

The command **`tools`** let you the ability to enter into docker (interactive bash session).

> Example:
> Enter docker shell
> ```bash
> ./kbuilder tool
> ```
>


# License

### *Krita Builder* is released under the GNU General Public License (version 3 or any later version).

**Krita Builder** is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version.

**Krita Builder** is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should receive a copy of the GNU General Public License along with **Krita Builder**. If not, see <https://www.gnu.org/licenses/>.
