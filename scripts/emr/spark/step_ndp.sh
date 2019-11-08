#!/bin/bash
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

# Change to the directory this script is in
WKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $WKDIR

# BEGIN FUNCTION DEFINITIONS

function parse_args(){

    # Parse script/command line arguments
    # input: string

    while [[ $# > 1 ]]; do
        key="$1"

        case $key in
            --sdlc)
            export SDLC="$2"
            shift
            ;;
            --ags)
            export AGS="$2"
            shift
            ;;
            --cert_file)
            export CERT_FILE="$2"
            shift
            ;;
            --ldap_fqdn)
            export LDAP_FQDN="$2"
            shift
            ;;
            --ldap_ip)
            export LDAP_IP="$2"
            shift
            ;;
            --ldap_base_dn)
            export LDAP_BASE_DN="$2"
            shift
            ;;
            --ldap_user_rdn)
            export LDAP_USER_RDN="$2"
            shift
            ;;
            --ldap_svc_rdn)
            export LDAP_SVC_RDN="$2"
            shift
            ;;
            --ldap_svc_user)
            export LDAP_SVC_USER="$2"
            shift
            ;;
            --ldap_group)
            export LDAP_GROUP="$2"
            shift
            ;;
            --ldap_group_rdn)
            export LDAP_GROUP_RDN="$2"
            shift
            ;;
            --run_secrets_cmd)
            export RUN_SECRETS_CMD="$2"
            shift
            ;;
            --jupyter_bucket)
            export JUPYTER_BUCKET="$2"
            shift
            ;;
            --ssm_document)
            export SSM_DOCUMENT="$2"
            shift
            ;;
            --idle_seconds)
            export IDLE_SECONDS="$2"
            shift
            ;;
            --mliy_targz_file)
            export MLIY_TARGZ_FILE="$2"
            shift
            ;;
            *)
            # unknown option
            ;;
        esac
    shift
    done
}

# END FUNCTION DEFINITIONS

# BEGIN ARGUMENTS

parse_args "$@"

# END ARGUMENTS

# BEGIN MAIN PROGRAM
sudo pip install awscli
aws s3 cp $CERT_FILE .
CERT_TARGZ=${CERT_FILE##*/}
tar xzf $CERT_TARGZ
sudo mv -f *.cer /etc/pki/tls/certs/localhost.crt
sudo mv -f *.key /etc/pki/tls/private/localhost.key


sudo yum install -y mod24_ldap mod24_ssl mod24_proxy_html

MASTER_IP=$(sudo ifconfig eth0 | egrep -o 'inet addr:[0-9.]+' | sed -e 's/inet addr://g' )

SVC_PASS=$(eval $RUN_SECRETS_CMD)

echo "$LDAP_IP $LDAP_FQDN" | sudo tee -a /etc/hosts

read -r -d '' HTML_PAGE <<EOF
<html><head><title>Notebook Development Platform</title></head>
<body>
<h1>Notebook Development Platform</h1>
<p>
Please use <mark>Your network credentials</mark> to logon to the following web-accessible services.
<ul>
<li><a href="/hub/">JupyterHub</a>
<li><a href="/livy/">Apache Livy</a>
<li><a href="/spark/">Apache Spark History Server</a>
<li><a href="/yarn/">Apache Hadoop Yarn</a>
<li><a href="/ganglia/">Ganglia</a>
</ul>
</p>
<hr>
<h2>Documentation</h2>
<p>
<a href="https://jupyterhub.readthedocs.io/en/stable/">JupyterHub</a>
</p>
<p>
<a href="https://github.com/jupyter-incubator/sparkmagic">Sparkmagic</a>
</p>
<p>
<a href="https://livy.incubator.apache.org/">Apache Livy</a>
</p>
<p>
<a href="https://spark.apache.org/docs/2.4.0/">Apache Spark</a>
</p>
<p>
<a href="https://hadoop.apache.org/docs/current/hadoop-yarn/hadoop-yarn-site/YARN.html">Apache Hadoop Yarn</a>
</p>
EOF

echo "$HTML_PAGE" > index.html
sudo mv index.html /var/www/html/

read -r -d '' MLIY_CONFIG <<EOF
LDAPVerifyServerCert Off
ServerSignature Off
ServerTokens Prod
Header always set Strict-Transport-Security "max-age=63072000; includeSubdomains;"
Listen 443 https

SSLPassPhraseDialog exec:/usr/libexec/httpd-ssl-pass-dialog
SSLSessionCache         shmcb:/run/httpd/sslcache(512000)
SSLSessionCacheTimeout  300
SSLRandomSeed startup file:/dev/urandom  256
SSLRandomSeed connect builtin
SSLCryptoDevice builtin

SetEnv proxy-sendchunks 1
LoadModule proxy_module modules/mod_proxy.so
LoadModule proxy_http_module modules/mod_proxy_http.so
LoadModule proxy_wstunnel_module modules/mod_proxy_wstunnel.so

<VirtualHost *:443>

ErrorLog logs/ssl_error_log
TransferLog logs/ssl_access_log
LogLevel warn
RewriteEngine On
ProxyRequests Off
#LogLevel alert rewrite:trace6

SSLEngine on
SSLProxyEngine on
SSLProxyCheckPeerCN off
SSLProxyCheckPeerName off
SSLProxyVerify none
SSLProxyCheckPeerExpire off
SSLProtocol all -SSLv2 -SSLv3 -TLSv1
SSLCertificateFile /etc/pki/tls/certs/localhost.crt
SSLCertificateKeyFile /etc/pki/tls/private/localhost.key
SSLHonorCipherOrder On
SSLCipherSuite ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS:!DES:!3DES:!RC4

<Files ~ "\.(cgi|shtml|phtml|php3?)$">
    SSLOptions +StdEnvVars
</Files>
<Directory "/var/www/cgi-bin">
    SSLOptions +StdEnvVars
</Directory>
BrowserMatch "MSIE [2-5]"          nokeepalive ssl-unclean-shutdown          downgrade-1.0 force-response-1.0

<LocationMatch "^/(livy|spark|yarn|ganglia)">

        AuthType Basic
        AuthBasicProvider ldap
        AuthName "LDAP Authentication"

        AuthLDAPURL "ldaps://${LDAP_FQDN}:636/${LDAP_USER_RDN},${LDAP_BASE_DN}?sAMAccountName?sub?(objectClass=*)"

        AuthLDAPBindDN "CN=${LDAP_SVC_USER},${LDAP_SVC_RDN},${LDAP_BASE_DN}"
        AuthLDAPBindPassword "${SVC_PASS}"

        AuthLDAPGroupAttribute member
        Require ldap-attribute memberOf="${LDAP_GROUP}"

</LocationMatch>

RedirectMatch permanent ^/spark$ /spark/
RedirectMatch permanent ^/ganglia$ /ganglia/
RedirectMatch permanent ^/yarn$ /yarn/
RedirectMatch permanent ^/livy$ /livy/
RedirectMatch permanent ^/hub$ /hub/

RewriteCond "%{HTTP_REFERER}"  "/(livy|ui|static/(fonts|css))/?"
RewriteRule "^/static/(.*)" "/livy/static/\$1" [L,P]

RewriteCond "%{HTTP_REFERER}"  "/(yarn|cluster|static/jquery)/"
RewriteRule "^/static/(.*)" "/yarn/static/\$1" [L,P]

RewriteCond "%{HTTP_REFERER}"  "/spark/" [OR]
RewriteCond "%{HTTP_REFERER}"  "showIncomplete=(true|false)$"
RewriteRule "^/static/(.*)" "/spark/static/\$1" [L,P]

RewriteRule "^/ui(.*)" "/livy/ui\$1" [L,P]

RewriteRule "^/sessions(.*)" "/livy/sessions\$1" [L,P]

RewriteRule "^/batches(.*)" "/livy/batches\$1" [L,P]

RewriteRule "^/cluster/(.*)" "/yarn/cluster/\$1" [L,P]

RewriteRule "^/conf" "/yarn/conf" [L,P]

RewriteRule "^/logs(.*)" "/yarn/logs/\$1" [L,P]

RewriteRule "^/stacks" "/yarn/stacks" [L,P]

RewriteRule "^/jmx(.*)" "/yarn/jmx\$1" [L,P]

RewriteRule "^/history/(.*)" "/spark/history/\$1" [L,P]

RewriteRule "^/api/(.*)" "/spark/api/\$1" [L,P]

RewriteRule "^/images/(.*)" "/spark/images/\$1" [L,P]

RewriteCond "%{QUERY_STRING}"  "^showIncomplete=(true|false)$"
RewriteRule "^/$" "/spark/" [L,P,QSA]

<Location /ganglia/>
ProxyPass        http://$MASTER_IP/ganglia/ timeout=86400 keepalive=On
ProxyPassReverse http://$MASTER_IP/ganglia/
</Location>

<Location /yarn/>
        ProxyPass http://$MASTER_IP:8088/ timeout=86400 keepalive=On
        ProxyPassReverse http://$MASTER_IP:8088/
</Location>

<Location /spark/>
        ProxyPass https://$MASTER_IP:18480/ timeout=86400 keepalive=On
        ProxyPassReverse https://$MASTER_IP:18480/
</Location>

<Location /livy/>
        ProxyPass http://$MASTER_IP:8998/ timeout=86400 keepalive=On
        ProxyPassReverse http://$MASTER_IP:8998/
</Location>

<Location /hub/>
        # preserve Host header to avoid cross-origin problems
        ProxyPreserveHost On
		ProxyPass http://$MASTER_IP:9443/hub/ timeout=86400 keepalive=On
		ProxyPassReverse http://$MASTER_IP:9443/hub/
</Location>

<Location ~ "/hub/user/[^/]+/(api/kernels|terminals/websocket)/">
        # preserve Host header to avoid cross-origin problems
        ProxyPreserveHost On
        ProxyPass ws://$MASTER_IP:9443 timeout=86400 keepalive=On
        ProxyPassReverse  ws://$MASTER_IP:9443
</Location>

</VirtualHost>
EOF

echo "$MLIY_CONFIG" > mliyemr.conf
sudo mv mliyemr.conf /etc/httpd/conf.d/

# Spark/Jupyterhub/EMR Cluster Steps
# AWS S3 Support

read -r -d '' JUPYTER_NOTEBOOK_CONFIG <<EOF
# Configuration file for jupyter-notebook.

from s3contents import S3ContentsManager

config = get_config()

# Tell Jupyter to use S3ContentsManager for all storage.
config.NotebookApp.contents_manager_class = S3ContentsManager
config.S3ContentsManager.bucket = "${JUPYTER_BUCKET}"
import os
user = os.environ['JUPYTERHUB_USER']
config.S3ContentsManager.prefix = os.path.join("jupyter", user)
config.S3ContentsManager.sse = "AES256"
config.S3ContentsManager.signature_version = "s3v4"
EOF

echo "$JUPYTER_NOTEBOOK_CONFIG" > jupyter_notebook_config.py
sudo mv jupyter_notebook_config.py /etc/jupyter/

read -r -d '' BOOTSTRAP <<'EOF'
#!/bin/bash

# - The first parameter for the Bootstrap Script is the USER.
USER=$1
if [ "$USER" == "" ]; then
    exit 1
fi
# ----------------------------------------------------------------------------

# This script will do the following:
# - create the user $USER in a Docker container jupyterhub with login and password disabled
# - create a the home directory /home/$USER for user to store Jupyterhub runtime files

# Start the Bootstrap Process
echo "bootstrap process running for user $USER ..."

# Base Directory: All Directories for the user will be below this point
BASE_DIRECTORY=/home

# User Directory: That's the private directory for the user to be created, if none exists
USER_DIRECTORY=$BASE_DIRECTORY/$USER

if [ getent passwd $USER > /dev/null 2>&1 ] || [ -d "$USER_DIRECTORY" ]; then
    echo "...user $USER already exists or directory for user $USER_DIRECTORY already exists. skipped"
    exit 0 # all good. nothing to do.
else
    echo "...creating account $USER and associated home directory $USER_DIRECTORY"
    adduser --quiet  --shell=/bin/bash --gecos GECOS --disabled-password --disabled-login $USER
    # adduser did not succeed?
    if [ $? -ne 0 ] ; then
        exit 1
        else
    # Disable blinking Cursor in Jupyterhub
    mkdir -p $USER_DIRECTORY/.jupyter/nbconfig

cat > $USER_DIRECTORY/.jupyter/nbconfig/notebook.json <<EOF1
{
  "CodeCell": {
    "cm_config": {
      "autoCloseBrackets": false,
      "cursorBlinkRate": 0
     }
   }
}
EOF1

    chown -R $USER:$USER $USER_DIRECTORY/.jupyter

    fi

fi

exit 0
EOF

echo "$BOOTSTRAP" > bootstrap.sh
chmod +x bootstrap.sh
sudo mv bootstrap.sh /etc/jupyter/conf/

read -r -d '' JUPYTERHUB_CONFIG <<EOF
# Configuration file for jupyterhub.

import os
from subprocess import check_call

def my_script_hook(spawner):
    username = spawner.user.name # get the username
    script = os.path.join(os.path.dirname(__file__), 'bootstrap.sh') # chmod +x bootstrap.sh
    check_call([script, username])

notebook_dir = os.environ.get('DOCKER_NOTEBOOK_DIR')
network_name='jupyterhub-network'

c.Spawner.debug = True
# attach the hook function to the spawner
c.Spawner.pre_spawn_hook = my_script_hook
c.Spawner.environment = {'SPARKMAGIC_CONF_DIR':'/etc/jupyter/conf', 'JUPYTER_ENABLE_LAB': 'yes'}

c.JupyterHub.hub_ip = '0.0.0.0'
c.JupyterHub.admin_access = True
c.JupyterHub.port = 9443

c.Authenticator.admin_users = {'jovyan'}
c.JupyterHub.base_url = '/hub/'

c.JupyterHub.authenticator_class = 'ldapauthenticator.LDAPAuthenticator'
c.LDAPAuthenticator.use_ssl = True
c.LDAPAuthenticator.server_address = '${LDAP_FQDN}'
c.LDAPAuthenticator.server_port = 636
c.LDAPAuthenticator.bind_dn_template = ['CN={username},${LDAP_USER_RDN},${LDAP_BASE_DN}']
c.LDAPAuthenticator.allowed_groups = ['${LDAP_GROUP}']
# Active Directory Integration
c.LDAPAuthenticator.lookup_dn = True
c.LDAPAuthenticator.lookup_dn_search_filter = '({login_attr}={login})'
c.LDAPAuthenticator.lookup_dn_search_user = 'CN=${LDAP_SVC_USER},${LDAP_SVC_RDN},${LDAP_BASE_DN}'
c.LDAPAuthenticator.lookup_dn_search_password = '${SVC_PASS}'
c.LDAPAuthenticator.user_search_base = '${LDAP_USER_RDN},${LDAP_BASE_DN}'
c.LDAPAuthenticator.user_attribute = 'sAMAccountName'
c.LDAPAuthenticator.lookup_dn_user_dn_attribute = 'cn'
c.LDAPAuthenticator.escape_userdn = False
EOF

echo "$JUPYTERHUB_CONFIG" > jupyterhub_config.py
sudo mv jupyterhub_config.py /etc/jupyter/conf/

sudo docker exec jupyterhub bash -c "pip install --upgrade s3contents"
sudo docker exec jupyterhub bash -c "pip install awscli"
# Copy info from the master node to docker container
sudo docker exec jupyterhub bash -c "mkdir -p /mnt/var/lib/info"
sudo docker cp /mnt/var/lib/info/job-flow.json jupyterhub:/mnt/var/lib/info/job-flow.json
sudo docker cp /mnt/var/lib/info/extraInstanceData.json jupyterhub:/mnt/var/lib/info/extraInstanceData.json

# Setup addlib_magic extension for iPython
aws s3 cp $MLIY_TARGZ_FILE .
MLIY_TARGZ=${MLIY_TARGZ_FILE##*/}

tar -zxvf "$MLIY_TARGZ" mliymagic meta_info.json
sudo docker exec jupyterhub bash -c "mkdir /opt/mliy"
sudo docker cp meta_info.json jupyterhub:/opt/mliy/
sudo docker cp mliymagic jupyterhub:/opt/mliy/
sudo docker exec jupyterhub bash -c "cd /opt/mliy/mliymagic; pip install ."
# Update the version of sparkmagic, install git and gcc
sudo docker exec jupyterhub bash -c "apt update; apt install -y gcc git; pip install -U sparkmagic"

# Set Auto-termination
SPARK_SCRIPTS=scripts/emr/spark
tar -zxvf "$MLIY_TARGZ" "$SPARK_SCRIPTS"/auto_terminate.sh
chmod 755 "$SPARK_SCRIPTS"/auto_terminate.sh
sudo mkdir -p /opt/mliy && sudo mv -f "$SPARK_SCRIPTS"/auto_terminate.sh /opt/mliy
cd /opt/mliy
sudo ./auto_terminate.sh setAutoTerminate --seconds "$IDLE_SECONDS"
cd -

# We're explicitly installing notebook here since s3 contents upgrades notebook to 6.0.0, which breaks things.
sudo docker exec jupyterhub bash -c "pip install notebook==5.7.8"
# Another hotfix related to pyspark3
sudo docker exec jupyterhub bash -c "sed -i 's/LANG_PYTHON3/LANG_PYTHON/g' /opt/conda/lib/python3.6/site-packages/sparkmagic/kernels/pyspark3kernel/pyspark3kernel.py"

sudo docker restart jupyterhub

sudo sed -i -e 's/^LogLevel .*/LogLevel info/g' /etc/httpd/conf/httpd.conf
cd /etc/httpd/conf.modules.d/
echo '#Commented out for MLiy Configuration' | sudo tee 00-dav.conf 00-lua.conf 00-proxy.conf 01-cgi.conf /etc/httpd/conf.d/ssl.conf
cd -
sudo /etc/init.d/httpd restart

exit 0

# END MAIN PROGRAM
