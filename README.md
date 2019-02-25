# FreeNAS Jails Setup

## Disclaimer

This project is not in any way designed to be a simple one-click-to-deploy project that let's you chose which software you want to run and can be tailored to your needs. It's my personal FreeNAS jails config that I use at home in order to synchronise my files between my workstations and file server as well as backing up everything present on my file server to remote services.

Because the jails configuration is heavily influenced by my personal tastes, you may prefer to just learn from it and take bits and pieces here and there rather than clone and run the whole thing as is.

## About the project

It leverages [FreeBSD Jails](https://www.freebsd.org/doc/handbook/jails.html) and [iocage](https://github.com/iocage/iocage) in order to containerize and run the services. The services that are hosted on the server are:

- [Syncthing](https://syncthing.net/): A simple service to synchronize your files between your hosts.
- [BorgBackup](https://www.borgbackup.org/) and [rclone](https://rclone.org/): Tools to backup my files. I'm still not set on them and how I'mn going to configure them.

## Roadmap

Project:

- Simplify the script by creating functions.
- Add more comments to explain my choices in the script.

## Prerequisites

- FreeNAS 11.1+ or FreeBSD 11.1+ with iocage installed

## Installation

```bash
git clone https://github.com/PlqnK/freenas-jails-setup.git
cd freenas-jails-setup
for file in *.example*; do cp $file $(echo $file | sed -e 's/.example//'); done
```

You then need to:

- Adapt the mount points in the script with what you have on your file server. You need to make it match the target 1:1, except for the source folder name which isn't important, otherwise you will need to modify every reference to the original target name in the script.
- Adapt the rest of the variables in the `jails-setup.conf` file according to your needs.

Next:

```bash
chmod u+x jails-setup.sh
sudo ./jails-setup.sh
```

## Contributing

Contributions are welcome if you see any area of improvement!

There's no specific guidelines for pull requests but keep in mind that this project is tailored to my needs and, for example, I might not agree with what you think should be added.

## License

This project is released under the [BSD 3-Clause License](https://opensource.org/licenses/BSD-3-Clause). A copy of the license is available in this project folder.
