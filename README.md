# ok-deploy
Composable One-Key Deploy Scripts for Ubuntu Server

**\<Work in Progress\>**

## What's included
Ubuntu server deploy scripts that suits wacky's tastes

#### essentials (run this first!)
* build-essentials
* vim
* [Monitors]: iftop, iotop, glances
* [Network]: traceroute, mtr

#### ssh
* only allows pubkey auth
* prompts for authorized_keys

#### hostname
* sets hostname

#### acme.sh
* acme.sh
* issues host ecc/rsa cert (if hostname is configured)

#### nginx
* mainline nginx from official nginx repo
* https redirection + ACME responder at `/var/acme-http`
* compose with [acme.sh](https://github.com/Neilpang/acme.sh)
* {tls-modern, proxy-headers} .incl for composable site configs
* <Caution>: will set HSTS includeSubdomains preload, USE AT YOUR OWN RISK

#### docker-ce
* docker community edition
* extra aufs packages (if found for running kernel version)

#### tinc-1.1
* tinc 1.1 from source
* compose with [tinc-config](https://github.com/wacky6/tinc-config)

#### node / node-lts
* node latest / latest-lts from source
* pm2 (from npm)
* swap addition (if host memory is small)
* yarn!

#### zsh
* zsh + [wacky's zshrc](https://github.com/wacky6/my_zshrc)
* sets default shell

## LICENSE
MIT (C) wacky6
