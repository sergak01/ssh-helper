# SSH key helper

Allows you to automatically add and remove the ssh key to / from the servers in the list, as well as check if the servers are accessible.

## Usage

```ssh
$ ./ssh-key-helper.sh -h
```

## Options

| Option | Usage | Default value | Description |
| :---: | :---: | --- | --- |
| `-m` | `-m check` | `check` | Current execution mode. Available values: `check` - check access to server; `add` - add public ssh key to the server; `remove` - remove public ssh key from server |
| `-p` | `-p ~/.ssh/id_rsa.pub` | None | The path to the public ssh key file to be added or deleted |
| `-i` | `-i ~/.ssh/id_rsa` | None | The path to the ssh private key file that will be used for the SSH `-i` option |
| `-d, --delimiter` | `-d ,` | `:` | Delimiter for text file. Can be automatically detected depending on the server file type |
| `-h` | `-h` | None | Show help |

## Params

| Param | Usage | Default value | Description |
| :---: | :---: | --- | --- |
| `serversListFile` | `./ssh-key-helper.sh ./servers.list` | `./servers.list` | Servers file list |

## Servers file list format

Blank lines will be skipped.
Lines beginning with # are considered comments and will be skipped while the script is running.

| Ip address/hostname | Port | Username | Status | Date |
|---|---|---|---|---|
| Required | Default: `22` | Default: `root` | None by default | None by default |
| `127.0.0.1` |||||

Example servers file: `./servers.list.example`

If `Status` in file is `success` or `not-found` then this line will be skipped.

`Date` only for info.
