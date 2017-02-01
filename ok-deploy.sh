#!/bin/bash
#
# wacky6
# LICENSE: MIT
#
# One-key deploy for ubuntu 16.04
#
########## Configuration ##########
# system
LOCALE="en_US.UTF-8"
TIMEZONE="Asia/Shanghai"

# ocserv
OC_PORT=3306
OC_NETWORK=192.168.7.0/24
OC_PASSWORD_BYTES=12

# ss-libev
SS_PORT=3389
SS_PASSWORD_BYTES=12
SS_METHOD=chacha20

# packages
PACKAGES="curl wget vim iperf3 mtr htop iotop iftop ethtool git"
NPM_PACKAGES="pm2"
NPM_PACKAGES_POST_INSTALL() {
	pm2 startup
}

# production directories
PRODUCTION_DIR="/node /git"

# server key/cert
ECC_KEY=/root/tls/server-ecc-key.pem
ECC_CERT=/root/tls/server-ecc-cert.pem
RSA_KEY=/root/tls/server-rsa-key.pem
RSA_CERT=/root/tls/server-rsa-cert.pem

# distro install command
UPDATE="apt update -y"
INSTALL="apt install -y"
INSTALL_MIN="${INSTALL} --no-install-recommends"
CLEANUP="apt autoremove -y"
ADDKEY="apt-key add -"
REPO_SOURCE=/etc/apt/sources.list

# distro (auto-detect)
DISTRO=`lsb_release -is | awk '{ print tolower($0) }'`
CODENAME=`lsb_release -cs | awk '{ print tolower($0) }'`

# acme http root
ACME_HTTP_ROOT=/var/acme-http/

# Num of CPU cores, set MAKE_OPTS -jN
CORES=`grep -c processor < /proc/cpuinfo`
MAKE_OPTS=-j${CORES}

SWAPFILE=/swapfile
LOG=/ok-deploy.log

########## Interactive Configuration ##########
echo "Please provide following informations -> "

# hostname
read -p "Hostname/FQDN (server.example.com): " FQDN

# ssh authorized keys
mkdir -p ~/.ssh/
AUTH_KEYS=~/.ssh/authorized_keys
touch ${AUTH_KEYS}
SSH_KEYS=`grep -c ssh- < ${AUTH_KEYS}`
SSHD_CONF=/etc/ssh/sshd_config
sshd-config() {
	# $1: option
	# $2: value
	# replace or append sshd option
	grep -q "${1} " ${SSHD_CONF} \
		&& sed -i "s/#\?${1} .*/${1} ${2}/" ${SSHD_CONF} \
		|| echo "${1} ${2}" >> ${SSHD_CONF}
}
if [ ${SSH_KEYS} -eq 0 ]; then
	echo 'Remove this line, paste in ssh authorized_keys' > ${AUTH_KEYS}
	${EDITOR:-vi} ${AUTH_KEYS}
	sshd-config PubkeyAuthentication yes
	sshd-config PermitRootLogin yes
	sshd-config PasswordAuthentication no
else
	echo "${SSH_KEYS} keys found, skip authorized_keys config."
fi
chmod 644 ${AUTH_KEYS}
service sshd reload

# ocserv client ca
TEMPFILE=`mktemp`
echo 'Paste in client ca certificate:' > ${TEMPFILE}
${EDITOR:-vi} ${TEMPFILE}
CLI_CERTS=`grep -c -e '-----BEGIN CERTIFICATE-----' < ${TEMPFILE}`
if [ ${CLI_CERTS} -ge 1 ] ; then
	echo "Get ${CLI_CERTS} certificates as client ca."
	OC_CLI_CA=${TEMPFILE}
else
	echo "No certificate found, will use username and password."
fi

# ocserv user name
read -p "OpenConnect user: " OC_USER

# ssh host keys
rm /etc/ssh/ssh_host_*
ssh-keygen -A
service ssh reload

echo "Regenerated SSH key fingerprints, please check at next login: "
for f in `ls /etc/ssh/ssh_host_*.pub`; do ssh-keygen -lf $f | awk '{ printf "    %-9s %4s %s\n", $4, $1, $2 }'; done

echo ""
echo "<!> Enter automatic deployment, check status by tail -f /ok-deploy.log"
echo "    Can now exit the shell/ssh"

########## Functions ##########
generate-password() {
	echo `dd if=/dev/random count=1 bs=${1:-12} 2>/dev/null | base64`
}
generate-ocserv-config() {
	# $1: config file
	cat > $1 <<- _EOF_
		auth = "plain[passwd=/etc/ocserv/ocpasswd]"
		enable-auth = "certificate"
		tcp_port = ${OC_PORT}
		run-as-user = nobody
		run-as-group = daemon
		socket-file = /var/run/ocserv-socket
		server-cert = ${SERVER_RSA_CERT}
		server-key = ${SERVER_RSA_KEY}
		ca-cert = /etc/ocserv/client-ca-chain.pem
		isolate-workers = true
		max-clients = 16
		max-same-clients = 2
		keepalive = 32400
		dpd = 90
		mobile-dpd = 1800
		try-mtu-discovery = false
		cert-user-oid = 2.5.4.3
		compression = true
		tls-priorities = "SECURE256:%SERVER_PRECEDENCE:%COMPAT:-VERS-SSL3.0"
		auth-timeout = 120
		min-reauth-time = 60
		max-ban-score = 50
		ban-reset-time = 300
		cookie-timeout = 300
		deny-roaming = false
		rekey-time = 172800
		rekey-method = ssl
		use-occtl = true
		pid-file = /var/run/ocserv.pid
		device = vpns
		predictable-ips = true
		ipv4-network = ${OC_NETWORK}
		dns = 8.8.8.8
		dns = 8.8.4.4
		cisco-client-compat = true
	_EOF_
	OC_PASSWORD=$( generate-password ${OC_PASSWORD_BYTES} )
	ocpasswd -u ${OC_USER} <<- _EOF_
		${OC_PASSWORD}
	_EOF_
}
generate-ss-libev-config() {
	# generate config
	SS_CONF=/etc/shadowsocks-libev/config.json
	SS_PASSWORD=$( generate-password ${SS_PASSWORD_BYTES} )
	mkdir -p `dirname ${SS_CONF}`
	cat > ${SS_CONF} <<-_EOF_
	{
	    "server_port": ${SS_PORT},
	    "password":    "${SS_PASSWORD}",
	    "method":      "${SS_METHOD}",
	    "timeout":     120,
	    "auth":        true
	}
	_EOF_
}
prepare() {
	local MEM=`cat /proc/meminfo | grep MemTotal | awk '{ print $2 }'`
	local SWAP=`cat /proc/meminfo | grep SwapTotal | awk '{ print $2 }'`
	local REQUIRED=$(( 1024*2000 ))
	# allocate swap if have insufficient memory
	if [ $(( ${MEM} + ${SWAP} )) -le ${REQUIRED} ]; then
		fallocate -l 2G ${SWAPFILE}
		chmod 600 ${SWAPFILE}
		swapon ${SWAPFILE}
	fi
	# mount tmpfs
	mount -t tmpfs tmpfs -o size=2G /tmp
	cd /tmp
}
cleanup() {
	cd /
	umount /tmp
	if [ -f ${SWAPFILE} ]; then
		swapoff ${SWAPFILE}
		rm -f ${SWAPFILE}
	fi
}

########## Deployment Scripts ##########
locale() {
	locale-gen ${LOCALE}
	export LANG=${LOCALE}
	export LC_ALL=${LOCALE}
	export LC_CTYPE=${LOCALE}
	cat > /etc/default/locale <<-_EOF_
		LC_ALL=${LC_ALL}
		LC_CTYPE=${LC_CTYLE}
		LANG=${LANG}
	_EOF_
}

timezone() {
	timedatectl set-timezone ${TIMEZONE}
}

kernel_and_bbr() {
	wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.9/linux-headers-4.9.0-040900_4.9.0-040900.201612111631_all.deb
	wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.9/linux-headers-4.9.0-040900-generic_4.9.0-040900.201612111631_amd64.deb
	wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.9/linux-image-4.9.0-040900-generic_4.9.0-040900.201612111631_amd64.deb
	dpkg -i ./linux-*.deb
	update-grub
	rm -r ./linux-*.deb

	# do not sysctl -p, reboot into new kernel is required to load bbr
	echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
	echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
}

_nginx() {
	curl http://nginx.org/keys/nginx_signing.key | ${ADDKEY}
	echo "deb http://nginx.org/packages/mainline/${DISTRO}/ ${CODENAME} nginx" >> ${REPO_SOURCE}
	echo "deb-src http://nginx.org/packages/mainline/${DISTRO}/ ${CODENAME} nginx" >> ${REPO_SOURCE}
	${UPDATE}
	${INSTALL} nginx
	# configure acme-challenge and redirects to https
	mkdir -p ${ACME_HTTP_ROOT}
	cat > /etc/nginx/conf.d/acme-http.conf <<-_EOF_
	server {
	    listen 80 default_server;
	    listen [::]:80 default_server;

	    root ${ACME_HTTP_ROOT};

	    location ~ /.well-known {
	        allow all;
	    }

	    location / {
	        return 301 https://$host$request_uri;
	    }
	}
	_EOF_
	systemctl enable nginx
	service nginx restart
}

_acme_sh() {
	# depends on nginx
	git clone --depth 1 https://github.com/Neilpang/acme.sh.git
	( cd acme.sh ; ./acme.sh --install )
	rm -r ./acme.sh

	for f in ${ECC_KEY} ${ECC_CERT} ${RSA_KEY} ${RSA_CERT}; do
		mkdir -p `dirname ${f}`
	done
	
	acme.sh --issue --keylength ec-256 --webroot ${ACME_HTTP_ROOT} --domain ${HOSTNAME} \
	        --fullchainpath ${ECC_CERT} \
			--keypath ${ECC_KEY}
	ECC_CERT_RESULT=$?
	
	acme.sh --issue --keylength 2048 --webroot ${ACME_HTTP_ROOT} --domain ${HOSTNAME} \
	        --fullchainpath ${RSA_CERT} \
			--keypath ${RSA_KEY}
	RSA_CERT_RESULT=$?
}

_nodejs() {
	local NODE_LATEST_LTS=`curl https://nodejs.org/dist/index.json 2>/dev/null | tac | grep -e '"lts":"[A-Z][a-z]\+"' | grep -oe '"version":"\(v[.0-9]\+\)"' | grep -oe 'v[.0-9]\+' | sort -rV | head -n1`
	local NODE_VER=${NODE_LATEST_LTS}
	local NODE_ARCHIVE=node-${NODE_VER}
	
	wget "https://nodejs.org/dist/${NODE_VER}/${NODE_ARCHIVE}.tar.gz"
	tar xf ${NODE_ARCHIVE}.tar.gz
	( cd ${NODE_ARCHIVE} ; ./configure && make ${MAKE_OPTS} install )
	rm -r ${NODE_ARCHIVE}
	
	npm i -g ${NPM_PACKAGES}
	NPM_PACKAGES_POST_INSTALL
}
_ocserv() {
	local OCSERV_FILE=`curl ftp://ftp.infradead.org/pub/ocserv/ 2>/dev/null | grep -oe 'ocserv-[.0-9]\+\.tar\.[a-z]\+' | sort -rV | head -n1`
	local OCSERV_VER=`echo "${OCSERV_FILE}" | grep -oe "[.0-9]\+[0-9]"`
	${INSTALL_MIN} \
		build-essential pkg-config autogen \
		libopts25 libopts25-dev libreadline6 libreadline6-dev liblz4-dev liblz4-1 \
		libev4 libev-dev libprotobuf-c-dev nettle-dev nettle-bin \
		gnutls-bin libgnutls28-dev
	wget ftp://ftp.infradead.org/pub/ocserv/${OCSERV_FILE}
	tar xf ${OCSERV_FILE}
	( cd "ocserv-${OCSERV_VER}" ; ./configure && make ${MAKE_OPTS} install )
	
	mkdir -p /etc/ocserv/
	cp ocserv-${OCSERV_VER}/doc/sample.config /etc/ocserv/ocserv.conf
	generate-ocserv-config /etc/ocserv/ocserv.conf

	# install systemd service
	cp ocserv-${OCSERV_VER}/doc/systemd/standalone/ocserv.service /etc/systemd/system/
	systemctl enable ocserv.service
	
	rm -r ocserv-${OCSERV_VER}
}

_ss_libev() {
	${INSTALL_MIN} \
		build-essential automake autoconf libtool libssl-dev gawk \
		debhelper dh-systemd init-system-helpers pkg-config asciidoc xmlto apg \
		libpcre3-dev zlib1g-dev libudns-dev libev4 libev-dev libmbedtls-dev
	# libsodium
	git clone --branch master --depth 1 https://github.com/jedisct1/libsodium.git
	( cd libsodium ; ./autogen.sh && ./configure && make ${MAKE_OPTS} install )
	rm -r libsodium
	# ss-libev -> debian package
	git clone --branch v2.6.3 --depth 1 https://github.com/shadowsocks/shadowsocks-libev
	( cd shadowsocks-libev ; git submodule update --init --recursive && ./autogen.sh && ./configure && dpkg-buildpackage -b -us -uc -i )
	# install built package
	dpkg -i shadowsocks-libev*.deb
	rm -r shadowsocks-libev*.deb
	rm -r shadowsocks-libev

	generate-ss-libev-config
	
	systemctl enable shadowsocks-libev
}

save-report() {
	local ACME_VERSION=`acme.sh --version`
	local NGINX_VERSION=`nginx -v && echo v$( nginx -v 2>&1 | awk '{print $3}' | tail -c+7 )`
	local NODE_VERSION=`node --version`
	local OCSERV_VERSION=`ocserv --version && echo v$( ocserv --version 2>&1 | head -n1 | awk '{print $2}' )`
	local SS_LIBEV_VERSION=`ss-server --help > /dev/null && echo v$( ss-server --help | grep shadowsocks-libev | awk '{print $2}' )`
	cat <<-_EOF_
		hostname: ${HOSTNAME}
		timezone: ${TIMEZONE}
		locale: ${LOCALE}

		acme.sh:  ${ACME_VERSION:-not installed}
		nginx:    ${NGINX_VERSION:-not installed}
		node.js:  ${NODE_VERSION:-not installed}
		ocserv:   ${OCSERV_VERSION:-not installed}
		ss-libev: ${SS_LIBEV_VERSION:-not installed}

	_EOF_

	# ssh host keys
	echo "ssh key fingerprints: "
	for f in `ls /etc/ssh/ssh_host_*.pub`; do ssh-keygen -lf $f | awk '{ printf "    %-9s %4s %s\n", $4, $1, $2 }'; done

	# ocserv
	if [ ${OCSERV_VERSION} ]; then
		cat <<-_EOF_
			ocserv:
			    port: ${OC_PORT}
			    user: ${OC_USER}
			    password: ${OC_PASSWORD}

		_EOF_
	fi

	if [ ${SS_LIBEV_VERSION} ]; then
		cat <<-_EOF_
			ss-libev:
			    port: ${SS_PORT}
			    method: ${SS_METHOD}
			    password: ${SS_PASSWORD}
			    ota: true

		_EOF_
	fi

	if [ ${ECC_CERT_RESULT} ]; then
		cat <<-_EOF_
			ecc cert issued:
			    key:  ${ECC_KEY}
			    cert: ${ECC_CERT}

		_EOF_
	else
		echo "<!> ecc cert NOT issued."
	fi

	if [ ${RSA_CERT_RESULT} ]; then
		cat <<-_EOF_
			rsa cert issued:
			    key:  ${RSA_KEY}
			    cert: ${RSA_CERT}

		_EOF_
	else
		echo "<!> rsa cert NOT issued."
		echo "    ocserv won't work properly!"
	fi
}

########## Main ##########
ok-deploy() {
	# system settings
	locale
	timezone

	# install essential packages
	${UPDATE}
	${INSTALL} build-essential coreutils git vim ${PACKAGES}

	# prepare env
	prepare

	# steps
	kernel_and_bbr
	_nginx
	_acme_sh
	_nodejs
	_ocserv
	_ss_libev

	${CLEANUP}

	save-report
}

ok-deploy
