#!/bin/bash 
# Script to setup MLiy
# The script expects environment variables as input

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

set -xv

# BEGIN MAIN PROGRAM

DATE=$(date +%m%d%Y%H%M%S)
MANAGER_URL="https://${MANAGER_HOSTNAME}"
PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)

# Install Yum Packages
yum install -y python34 mod24_ldap mod24_ssl mod24_wsgi-python34 python34-pip python34-devel mysql-devel git gcc  

# Replace parameters
sed -i -e "s|{{{staging_bucket}}}|$SOURCE_BUCKET|g" mliyweb/settings.py
sed -i -e "s|{{{mliymgr_location}}}|$MANAGER_URL|g" mliyweb/settings.py
sed -i -e "s|{{{django_secret_key}}}|$DJANGO_SECRET_KEY|g" mliyweb/settings.py
sed -i -e "s|{{{hostname}}}|${MANAGER_HOSTNAME}|g" mliyweb/settings.py

if [[ "$PRIVATE_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
	sed -i -e "s|{{{private_ip}}}|${PRIVATE_IP}|g" mliyweb/settings.py
else
	sed -i -e "s|{{{private_ip}}}||g" mliyweb/settings.py
fi

if [[ "$PUBLIC_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
	sed -i -e "s|{{{public_ip}}}|${PUBLIC_IP}|g" mliyweb/settings.py
else
	sed -i -e "s|{{{public_ip}}}||g" mliyweb/settings.py
fi

sed -i -e "s|{{{dns_service}}}|${DNS_SERVICE}|g" plugin/plugin_settings.py
sed -i -e "s|{{{domain_name}}}|${DOMAIN_NAME}|g" plugin/plugin_settings.py
cd $INSTALL_BASE


# Create MLIY setup file

cat << EOF > runme-as-mliyapp.sh
# Setup proxy if needed
if [[ -f mliyweb/scripts/proxy.sh ]]; then
  source mliyweb/scripts/proxy.sh
fi

cd ~mliyapp
virtualenv -p /usr/bin/python3.4 mliy-python

source mliy-python/bin/activate

pip install -r mliyweb/mliyweb/requirements.txt

cd mliyweb
python manage.py makemigrations 
python manage.py migrate 
python manage.py makemigrations mliyweb
python manage.py migrate
python manage.py loaddata simpledb
python manage.py loaddata instances

EOF

chown -R mliyapp $INSTALL_BASE
chmod -R 755 $INSTALL_BASE

echo "Creating Python Virtual Environment"
echo `echo 0 | alternatives --config python 2>/dev/null | grep 'python3.4' | awk '{print $1}' |  tail -1` >  no_of_python_versions.txt
cat no_of_python_versions.txt | alternatives --config python && rm -f no_of_python_versions.txt

# Setup proxy if needed
if [[ -f mliyweb/scripts/proxy.sh ]]; then
  source mliyweb/scripts/proxy.sh
fi

pip install --upgrade virtualenv

su - mliyapp -c 'bash -xv runme-as-mliyapp.sh'


# HTTPD Configuration
if [[ ! -z "$LDAP_AUTH_URL" ]]; then
  LDAP_CONFIG=$(cat <<END_HEREDOC
<Location />
  AuthType Basic
  AuthBasicProvider ldap
  AuthName "LDAP Authentication"
  AuthLDAPURL "$LDAP_AUTH_URL"
  AuthLDAPBindDN "$LDAP_BIND_DN"
  AuthLDAPBindPassword "$LDAP_BIND_PASSWORD"
  AuthLDAPGroupAttribute member
  Require ldap-attribute memberOf="$LDAP_GROUP_ATTRIBUTE"
</Location>
END_HEREDOC
)
else
  LDAP_CONFIG=''  
fi


cat > /etc/httpd/conf.d/mliyweb.conf <<EOF
ServerSignature Off
ServerTokens Prod
IncludeOptional "/etc/httpd/conf.modules.d/*.conf"
Header always set Strict-Transport-Security "max-age=63072000; includeSubdomains;"
Listen 443 https
SSLPassPhraseDialog exec:/usr/libexec/httpd-ssl-pass-dialog
SSLSessionCache         shmcb:/run/httpd/sslcache(512000)
SSLSessionCacheTimeout  300
SSLRandomSeed startup file:/dev/urandom  256
SSLRandomSeed connect builtin
SSLCryptoDevice builtin

#LDAPVerifyServerCert Off


<VirtualHost *:80>
    RewriteEngine On
    RewriteRule (.*) https://%{HTTP_HOST}$1 [R=301]
    ServerName $MANAGER_HOSTNAME
</VirtualHost>

<VirtualHost *:443>
    ServerName $MANAGER_HOSTNAME
    ErrorLog logs/ssl_error_log
    TransferLog logs/ssl_access_log
    #LogLevel Debug


    LogLevel warn
    SSLEngine on

    SSLProtocol all -TLSv1 -SSLv2 -SSLv3
    SSLProxyProtocol all -TLSv1 -SSLv2 -SSLv3
    SSLHonorCipherOrder on
    SSLCipherSuite ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS:!DES:!3DES:!RC4:EECDH+AES128:RSA+AES128:EECDH+AES256:RSA+AES256
    SSLCertificateFile /etc/pki/tls/certs/localhost.crt
    SSLCertificateKeyFile /etc/pki/tls/private/localhost.key

    <Files ~ "\.(cgi|shtml|phtml|php3?)$">
        SSLOptions +StdEnvVars
    </Files>
    <Directory "/var/www/cgi-bin">
        SSLOptions +StdEnvVars
    </Directory>
    BrowserMatch "MSIE [2-5]" \
             nokeepalive ssl-unclean-shutdown \
             downgrade-1.0 force-response-1.0
    LogLevel info
    WSGIDaemonProcess mliyweb display-name=%{GROUP} user=mliyapp group=mliyapp python-path=/home/mliyapp/mliyweb:/home/mliyapp/mliy-python/lib64/python3.4/site-packages:/home/mliyapp/mliy-python/lib64/python3.4:/usr/lib64/python3.4/site-packages:/usr/lib64/python3.4:/usr/lib64/python3.4/lib-dynload

    WSGIProcessGroup mliyweb
    Alias /static/admin/ /home/mliyapp/mliy-python/lib64/python3.4/site-packages/django/contrib/admin/static/admin/
    Alias /static/ /home/mliyapp/mliyweb/mliyweb/static/
    WSGIScriptAlias / /home/mliyapp/mliyweb/mliyweb/wsgi.py

    <Directory /home/mliyapp/mliyweb/mliyweb>
        <Files wsgi.py>
            Order allow,deny
            Allow from all
            Require all granted
        </Files>
    </Directory>
    <Directory /home/mliyapp/mliyweb/mliyweb/static>
        Order allow,deny
        Allow from all
        Require all granted
    </Directory>
    ${LDAP_CONFIG}
    <Location /health>
        Order allow,deny
        Allow from all
        Require all granted
    </Location>
    <Location /static>
        Order allow,deny
        Allow from all
        Require all granted
    </Location>
    <Location /ajax/progress>
        Order allow,deny
        Allow from all
        Require all granted
    </Location>
</VirtualHost>
EOF

echo '#disabled for MLIY' | tee /etc/httpd/conf.d/{ssl,autoindex,userdir,welcome}.conf

chown root:root /etc/httpd/conf/*
chmod -R u=rwX,go-w /etc/httpd/conf

apachectl stop
sleep 1
chkconfig --add httpd
apachectl stop
apachectl start

# Repeat chmod for static files (e.g. css) that are generated by django
chmod -R 755 $INSTALL_BASE

# END MAIN PROGRAM