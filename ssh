#!/bin/bash

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

