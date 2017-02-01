# ok-deploy
One-key production environment deployment

## What's deployed
* system settings (Hostname, Locale, Timezone, etc.)
* kernel 4.9.0 + bbr
* acme.sh
* nginx (mainline), acme challenge + 301 redirect to https
* node.js (latest LTS)
* shadowsocks-libev (latest, from github)
* ocserv (latest)

if hostname (FQDN, to be precise) is provided:
* letsencrypt ecc+rsa cert
* configures ocserv

## Customize
Navigate to section: (inside vim): search `### [section]`. Section can be: `Configuration, Main`

## LICENSE
MIT (C) wacky6
