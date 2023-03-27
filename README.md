# ok-deploy
Composable One-Key Deploy Scripts for Ubuntu Server

## What's included
Ubuntu server deploy scripts that suits wacky's tastes

#### essentials (run this first!)
* build-essentials
* vim
* unattended-upgrades for all packages
* [Monitors]: iftop, iotop, glances
* [Network]: traceroute, mtr
* [Utils]: jq, iproute2, sed

#### ssh
* only allows pubkey auth
* prompts for authorized_keys

#### https
* compose with `./nginx`
* installs acme.sh, issues host ecc cert
* configs nginx public https static hosting at `/publish`
* sets CloudFlare DNS record (set `CF_Email`+`CF_Key` or `CF_Account_ID`+`CF_Token` before running)
* TODO: fetch CF_Email / CF_Key from remote (with .htpasswd)

#### nginx
* compose with `./https`
* mainline nginx from official nginx repo
* https redirection + ACME responder at `/var/acme-http`
* {tls-modern, proxy-headers} .incl for composable site configs
* <Caution>: will set HSTS includeSubdomains preload, USE AT YOUR OWN RISK

#### docker-ce
* docker community edition

#### tinc-1.1
* tinc 1.1 from source
* compose with [tinc-config](https://github.com/wacky6/tinc-config)

#### zsh
* zsh + [wacky's zshrc](https://github.com/wacky6/my_zshrc)
* sets default shell

#### code-server
* latest [code-server](https://github.com/coder/code-server)
* can run in crontab to do regular updates

## LICENSE
MIT (C) wacky6
