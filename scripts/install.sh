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
PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed 's/[a-z]$//'`"

mkdir /opt/mliy
cp meta_info.json /opt/mliy

# Install Yum Packages
yum install -y python34 mod24_ldap mod24_ssl mod24_wsgi-python34 python34-pip python34-devel mysql-devel git gcc

# Replace required parameters
sed -i -e "s|{{{time_zone}}}|$TIME_ZONE|g" mliyweb/settings.py
sed -i -e "s|{{{language_code}}}|$LANGUAGE_CODE|g" mliyweb/settings.py
sed -i -e "s|{{{staging_bucket}}}|$SOURCE_BUCKET|g" mliyweb/settings.py
sed -i -e "s|{{{django_secret_key}}}|$DJANGO_SECRET_KEY|g" mliyweb/settings.py
sed -i -e "s|{{{hostname}}}|${MANAGER_HOSTNAME}|g" mliyweb/settings.py
sed -i -e "s|{{{app_dns}}}|${APP_DNS}|g" mliyweb/settings.py
sed -i -e "s|{{{dns_service}}}|${DNS_SERVICE}|g" mliyweb/settings.py
sed -i -e "s|{{{domain_name}}}|${DOMAIN_NAME}|g" mliyweb/settings.py
sed -i -e "s|{{{ldap_admin_group_attribute}}}|${LDAP_ADMIN_GROUP_ATTRIBUTE}|g" mliyweb/settings.py

# Replace optional parameters and set the default values to blank
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

if [[ ! -z "$DNS_API_URL" ]]; then
	sed -i -e "s|{{{dns_api_url}}}|${DNS_API_URL}|g" mliyweb/settings.py
else
	sed -i -e "s|{{{dns_api_url}}}||g" mliyweb/settings.py
fi

if [[ ! -z "$DNS_MLIY_DOMAIN" ]]; then
	sed -i -e "s|{{{dns_mliy_domain}}}|${DNS_MLIY_DOMAIN}|g" mliyweb/settings.py
else
	sed -i -e "s|{{{dns_mliy_domain}}}||g" mliyweb/settings.py
fi

if [[ ! -z "$DNS_API_DATA" ]]; then
	sed -i -e "s|{{{dns_api_data}}}|${DNS_API_DATA}|g" mliyweb/settings.py
else
	sed -i -e "s|{{{dns_api_data}}}||g" mliyweb/settings.py
fi

if [[ ! -z "$DB_TYPE" ]]; then
	sed -i -e "s|{{{db_type}}}|${DB_TYPE}|g" mliyweb/settings.py
else
	sed -i -e "s|{{{db_type}}}||g" mliyweb/settings.py
fi

if [[ ! -z "$DB_NAME" ]]; then
	sed -i -e "s|{{{db_name}}}|${DB_NAME}|g" mliyweb/settings.py
else
	sed -i -e "s|{{{db_name}}}||g" mliyweb/settings.py
fi

if [[ ! -z "$DB_HOST" ]]; then
	sed -i -e "s|{{{db_host}}}|${DB_HOST}|g" mliyweb/settings.py
else
	sed -i -e "s|{{{db_host}}}||g" mliyweb/settings.py
fi

if [[ ! -z "$DB_USER" ]]; then
	sed -i -e "s|{{{db_user}}}|${DB_USER}|g" mliyweb/settings.py
else
	sed -i -e "s|{{{db_user}}}||g" mliyweb/settings.py
fi

if [[ ! -z "$DB_PASSWD" ]]; then
	sed -i -e "s|{{{db_passwd}}}|${DB_PASSWD}|g" mliyweb/settings.py
else
	sed -i -e "s|{{{db_passwd}}}||g" mliyweb/settings.py
fi

# Dafault is to use route 53 in AWS but if not, use DNS API tokens
if [[ "${DNS_SERVICE}" != 'aws' ]]; then
	mkdir deactivated && mv plugin/dns.py deactivated/route53.py && mv plugin/dns_api.py plugin/dns.py
fi

cd "$INSTALL_BASE"

# Setup proxy if needed
EXECUTE_PROXY_SCRIPT=''
if [[ ! -z "$PROXY_SCRIPT" && -f "mliyweb/scripts/$PROXY_SCRIPT" ]]; then
  source "mliyweb/scripts/$PROXY_SCRIPT"
  EXECUTE_PROXY_SCRIPT="source mliyweb/scripts/$PROXY_SCRIPT"
fi

# Initialize Database
if [[ ! -z "$DB_INIT" && "$DB_INIT" == 'TRUE'  ]]; then
DB_INIT_SCRIPT=$(cat <<END_HEREDOC
python manage.py loaddata simpledb
python manage.py loaddata instances
END_HEREDOC
)
else
DB_INIT_SCRIPT=''
fi


if [[ ! -z "$INSTANCE_PRICING" && "$INSTANCE_PRICING" == 'TRUE'  ]]; then
    curl -L http://www.ec2instances.info/instances.json > mliyweb/mliyweb/prices/instances.json
else
    echo 'Using pre-downloaded instance pricing.'
fi

# Create MLIY setup file

cat << EOF > runme-as-mliyapp.sh
${EXECUTE_PROXY_SCRIPT}

cd ~mliyapp
mkdir -p mliy-python
virtualenv -p /usr/bin/python3.4 mliy-python

source mliy-python/bin/activate

pip install -r mliyweb/mliyweb/requirements.txt

cd mliyweb
python manage.py makemigrations
python manage.py migrate
python manage.py makemigrations mliyweb
python manage.py migrate
python manage.py sync_cf
${DB_INIT_SCRIPT}

EOF

chown -R mliyapp "$INSTALL_BASE"
chmod -R 755 "$INSTALL_BASE"

echo "Creating Python Virtual Environment"
echo `echo 0 | alternatives --config python 2>/dev/null | grep 'python3.4' | awk '{print $1}' |  tail -1` >  no_of_python_versions.txt
cat no_of_python_versions.txt | alternatives --config python && rm -f no_of_python_versions.txt

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

if [[ ! -z "$DISABLE_LDAP_CERT_VALIDATION" && "$DISABLE_LDAP_CERT_VALIDATION" == 'true' ]]; then
	LDAP_VERIFY_SERVER_CERT='LDAPVerifyServerCert Off'
else
	LDAP_VERIFY_SERVER_CERT=''
fi

cat > /etc/httpd/conf.d/mliyweb.conf <<EOF
ServerName localhost
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

${LDAP_VERIFY_SERVER_CERT}

<VirtualHost *:80>
    RewriteEngine On
    RewriteRule (.*) https://%{HTTP_HOST}$1 [R=301]
</VirtualHost>

<VirtualHost *:443>
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
chmod -R 755 "$INSTALL_BASE"

# Setup SSM documents
META_INFO_AGS=$(grep app_id /opt/mliy/meta_info.json | awk -F ':' '{print $2}' | sed -e 's/[" ]//g')
cd mliyweb/mliymagic/mliymagic

for ITEM in addlib pip-install; do
    SSM_DOCUMENT_NAME=$(python -c "import json,utils; doc = utils.get_ssm_document('$ITEM'); print (doc['name'])")
    SSM_DOCUMENT_CONTENT=$(python -c "import json,utils; doc = utils.get_ssm_document('$ITEM'); print (json.dumps(doc['content']))")
    ITEM_EXISTS=$(aws ssm list-documents --filters "Key=Name,Values=$META_INFO_AGS-$ITEM" --region="$EC2_REGION" | grep DocumentVersion | wc -l)
    if [[ "$ITEM_EXISTS" -gt "0" ]]; then
        aws ssm delete-document --name "$SSM_DOCUMENT_NAME" --region "$EC2_REGION"
    fi
    aws ssm create-document --name "$SSM_DOCUMENT_NAME" --content "$SSM_DOCUMENT_CONTENT" --document-type "Command" --document-format JSON --target-type /AWS::EC2::Instance --region "$EC2_REGION"
done

# END MAIN PROGRAM
