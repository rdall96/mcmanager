#  MCManager

MCManager is a standalone application to manage Minecraft servers. It allows multiple users to create and configure as many instances as they like all at the same time.

**Highlights:
- It is written in Swift, and it runs a local HTTP server using [Vapor](https://vapor.codes).
- Minecraft servers are managed with custom made [Docker](https://www.docker.com) containers supporting all versions of Minecraft, with mod loaders included.

---

## System Requirements

- [Docker](https://www.docker.com)
- RAM: 4GB (minimum), 16GB+ (recommended) - The more RAM the better if you want to run multiple Minecraft servers
- Storage: 16GB (minimum), 64GB (recommended)

---

## Installation

TBD

---

## Bug reports

Please report any bugs or feature request at [MCManager Support](mailto:contact-project+mcmanager-mcmanager-47705503-issue-@incoming.gitlab.com).

---

## Development

There are two options when it comes to developing for MCManager:

**Xcode**

Open this repository with Xcode and get started immediately.
The default run target will run the application in `DEBUG` mode in your default DerivedData folder, so all project data (i.e.: database, minecraft servers, etc...) can easily be deleted by cleaning the build.

**Docker**

Open the project with your text editor of choice, and build any changes using Docker.

```
$ cd mcmanager
$ docker build . -t mcmanager:dev
```
