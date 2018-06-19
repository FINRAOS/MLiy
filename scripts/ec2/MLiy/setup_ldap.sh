# Setup LDAP Authentication and Authorization
# The script must be sourced by install_MLiy.sh

# Copyright 2017 MLiy Contributors

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Change to Analyst home directory to install/configure 
cd ~analyst

#Setup nss-pam-ldapd package
cd nss-pam-ldapd-0.9.7
./configure -q && make >/dev/null 
make install 
ln -s /lib/libnss_ldap.so.2 /lib64/libnss_ldap.so.2
ln -s /lib/security/pam_ldap.so /lib64/security/pam_ldap.so
cat > /etc/init.d/nslcd <<'EOF'
#!/bin/sh
#
# chkconfig: - 12 88 
# description: Provides naming services using a directory server.
# processname: /usr/sbin/nslcd
# config: /etc/nslcd.conf
# pidfile: /var/run/nslcd/nslcd.pid
#

### BEGIN INIT INFO
# Provides: nslcd
# Required-Start: $network
# Required-Stop:
# Default-Start:
# Default-Stop:
# Short-Description: naming services LDAP client daemon
# Description: Provides naming services using a directory server.
### END INIT INFO
program=/sbin/nslcd
prog=${program##*/}
pidfile=/var/run/nslcd/nslcd.pid

if [ -f /etc/rc.d/init.d/functions ]; then
	. /etc/rc.d/init.d/functions
fi

RETVAL=0

LOGGER="/usr/bin/logger -t $prog"
myEcho () {
    echo "$1"
    $LOGGER "$1"
}

start() {
    myEcho "Obtaining LDAP password from CredStash"
    LDAP_USER_PASSWD="$(LDAP_USER_PASSWD_CMD_TOKEN)"
    if [[ ! -z "$LDAP_USER_PASSWD" ]]; then
        myEcho "Checking if the LDAP password has changed"
        if ! grep -Fq $LDAP_USER_PASSWD /etc/nslcd.conf; then
            myEcho "Replacing LDAP password in /etc/nslcd.conf and /etc/pam_ldap.conf"
            ldap_user_passwd=$LDAP_USER_PASSWD perl -pi -e  's/^bindpw.*$/bindpw $ENV{ldap_user_passwd}/' /etc/nslcd.conf
            ldap_user_passwd=$LDAP_USER_PASSWD perl -pi -e  's/^bindpw.*$/bindpw $ENV{ldap_user_passwd}/' /etc/pam_ldap.conf
            fi
    fi
	echo -n $"Starting $prog: "
    daemon $program
    RETVAL=$?
    echo
    [ $RETVAL -eq 0 ] && touch /var/lock/subsys/$prog
    return $RETVAL
}

stop() {
    echo -n $"Stopping $prog: "
    killproc $program
    RETVAL=$?
    echo
    if [ $RETVAL -eq 0 ]; then
	rm -f /var/lock/subsys/$prog
    fi
}

restart() {
    stop
    start
}

# See how we were called.
case "$1" in
    start)
        [ -f /var/lock/subsys/$prog ] && exit 0
        $1
        ;;
    stop)
        [ -f /var/lock/subsys/$prog ] || exit 0
        $1
        ;;
    restart)
        $1
        ;;
    status)
        status -p $pidfile $program
        RETVAL=$?
        ;;
    condrestart|try-restart)
        [ -f /var/lock/subsys/$prog ] && restart || :
        ;;
    reload)
        echo "can't reload configuration, you have to restart it"
        RETVAL=3
        ;;
    force-reload)
        restart
        ;;
    *)
        echo $"Usage: $0 {start|stop|status|restart|condrestart|try-restart|reload|force-reload}"
        exit 1
        ;;
esac
exit $RETVAL
EOF
sed -i -e "s|LDAP_USER_PASSWD_CMD_TOKEN|$LDAP_USER_PASSWD_CMD|" /etc/init.d/nslcd
chmod 755 /etc/init.d/nslcd
groupadd nslcd
useradd -M -s /sbin/nologin -g nslcd nslcd
echo "service nslcd start" >> /etc/rc.d/rc.local

cat > /etc/nslcd.conf <<EOF
uid nslcd
gid nslcd
ldap_version 3
uri ldaps://${LDAP_HOST_NAME}/
ignorecase yes
base ${LDAP_BASE_DN}
binddn ${LDAP_USER_BIND_DN}
bindpw ${LDAP_USER_PASSWD}
ssl no
tls_reqcert hard
tls_cacertfile /etc/ssl/certs/ca-bundle.crt 
pagesize 1000
bind_timelimit 30
timelimit 30
scope sub
referrals no

filter passwd (&(objectClass=user)(memberOf=${LDAP_AUTHZ_GROUP}))
map    passwd uid              sAMAccountName 
map    passwd gecos            displayName
map    passwd loginShell       "/bin/bash"
map    passwd homeDirectory    "/ext/home/analyst"
map    passwd uidNumber        objectSid:S-1-5-21-2609389297-2041493788-1438465508
map    passwd gidNumber        "10001"
filter shadow (&(objectClass=user)(memberOf=${LDAP_AUTHZ_GROUP}))
map    shadow uid              sAMAccountName 
map    shadow shadowLastChange pwdLastSet
filter group  (objectClass=group)
EOF

cat > /etc/pam_ldap.conf <<EOF
ldap_version 3
uri ldaps://${LDAP_HOST_NAME}/
base ${LDAP_BASE_DN}
binddn ${LDAP_USER_BIND_DN}
bindpw ${LDAP_USER_PASSWD}
ssl no
tls_reqcert hard
tls_cacertfile /etc/ssl/certs/ca-bundle.crt 
bind_timelimit 30
bind_timelimit30
scope sub
referrals no
pam_login_attribute sAMAccountName
pam_filter objectClass=user
EOF

cat > /etc/nsswitch.conf <<EOF
passwd:     files sss ldap [NOTFOUND=return UNAVAIL=return]
shadow:     files sss ldap [NOTFOUND=return UNAVAIL=return]
group:      files sss 
hosts:      files dns
bootparams: nisplus [NOTFOUND=return] files
ethers:     files
netmasks:   files
networks:   files
protocols:  files
rpc:        files
services:   files sss
netgroup:   files sss 
publickey:  nisplus
automount:  files 
aliases:    files nisplus
EOF

cat > /etc/pam.d/password-auth-ac <<EOF
auth        required      pam_env.so
auth        sufficient    pam_unix.so nullok try_first_pass 
auth        requisite     pam_succeed_if.so uid >= 600 quiet_success
auth        sufficient    pam_ldap.so use_first_pass 
auth        required      pam_deny.so

account     required      pam_unix.so broken_shadow 
account     sufficient    pam_localuser.so
account     sufficient    pam_succeed_if.so uid < 600 quiet
account     [default=bad success=ok user_unknown=ignore] pam_ldap.so 
account     required      pam_permit.so

password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=	minlen=14	dcredit=-1	ucredit=-1	ocredit=-1	lcredit=-1
password    sufficient    pam_unix.so md5 shadow nullok try_first_pass use_authtok 
password    required      pam_deny.so

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
-session     optional      pam_systemd.so
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so 
EOF

cat > /etc/pam.d/rstudio <<EOF
auth      requisite      pam_succeed_if.so uid >= 600 quiet
auth      required       pam_ldap.so 

account   required       pam_ldap.so
EOF

cat > /etc/pam.d/httpd <<EOF
auth    required   pam_ldap.so
account required   pam_ldap.so
EOF

cd ~analyst
#Setup mod_authnz_pam package
cd mod_authnz_pam-1.0.2
apxs -i -a -c mod_authnz_pam.c -lpam -Wall -pedantic >/dev/null

cd ~analyst
rm -rf nss-pam-ldapd-0.9.7 mod_authnz_pam-1.0.2

cd $SCRIPT_DIR