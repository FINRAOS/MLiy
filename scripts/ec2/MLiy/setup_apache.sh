# Setup Apache Configuration
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

# Apache:  Deleting these would cause yum update to re-create them, so we overwrite.
cd /etc/httpd/conf.modules.d/
echo '#Commented out for UDSP' | tee 00-dav.conf 00-lua.conf 00-proxy.conf 01-cgi.conf /etc/httpd/conf.d/ssl.conf

# Change to Analyst home directory to install/configure 
cd ~analyst

# Setup Apache

if [[ ! -z "${WILDCARD_CERTS_ARCHIVE}" ]]; then
    tar xzf ${WILDCARD_CERTS_ARCHIVE}
    cp ${WILDCARD_PUBLIC_CERT} /etc/pki/tls/certs/
    chmod 600 /etc/pki/tls/certs/${WILDCARD_PUBLIC_CERT}
    cp ${WILDCARD_PRIVATE_CERT} /etc/pki/tls/private/
    chmod 600 /etc/pki/tls/private/${WILDCARD_PRIVATE_CERT}
else
	WILDCARD_PUBLIC_CERT='localhost.crt'
	WILDCARD_PRIVATE_CERT='localhost.key'
fi


cat > /etc/httpd/conf.d/odapserver.conf <<EOF
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

<VirtualHost *:80>
RewriteEngine On
RewriteRule (.*) https://%{HTTP_HOST} [R=301]
</VirtualHost>
<VirtualHost *:443>
RewriteEngine On
RewriteRule "/(.*\.woff2)$" "http://localhost:6006/$1" [P]
RedirectMatch permanent ^/rstudio$ /rstudio/
RedirectMatch permanent ^/ipython$ /ipython/
RedirectMatch permanent ^/flow$ /flow/ 
RedirectMatch permanent ^/tensorboard$ /tensorboard/ 
ErrorLog logs/ssl_error_log
TransferLog logs/ssl_access_log
LogLevel warn
SSLEngine on
SSLProtocol all -SSLv2 -SSLv3 -TLSv1
SSLCertificateFile /etc/pki/tls/certs/${WILDCARD_PUBLIC_CERT}
SSLCertificateKeyFile /etc/pki/tls/private/${WILDCARD_PRIVATE_CERT}
SSLHonorCipherOrder On
SSLCipherSuite ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS:!DES:!3DES:!RC4

<Files ~ "\.(cgi|shtml|phtml|php3?)$">
    SSLOptions +StdEnvVars
</Files>
<Directory "/var/www/cgi-bin">
    SSLOptions +StdEnvVars
</Directory>
BrowserMatch "MSIE [2-5]"          nokeepalive ssl-unclean-shutdown          downgrade-1.0 force-response-1.0

<Location /rstudio/>
ProxyPass        http://localhost:8787/ timeout=86400 keepalive=On
ProxyPassReverse http://localhost:8787/
</Location>
<Location /shiny/>
AuthType basic
AuthName "Shiny Server"
AuthBasicProvider PAM
AuthPAMService httpd
Require valid-user
ProxyPass        http://localhost:3838/ timeout=86400 keepalive=On
ProxyPassReverse http://localhost:3838/
RequestHeader set Origin "http://localhost:3838"
</Location>
<Location /ipython/>
AuthType basic
AuthName "Jupyter"
AuthBasicProvider PAM
AuthPAMService httpd
Require valid-user
ProxyPass        http://localhost:8080/ipython/ timeout=86400 keepalive=On
ProxyPassReverse http://localhost:8080/ipython/
RequestHeader set Origin "http://localhost:8080"
</Location>
<Location /ipython/api/kernels/>
ProxyPass               ws://localhost:8080/ipython/api/kernels/ timeout=86400 keepalive=On
ProxyPassReverse        ws://localhost:8080/ipython/api/kernels/
</Location>
<Location /ipython/terminals/websocket/>
ProxyPass       ws://localhost:8080/ipython/terminals/websocket/ timeout=86400 keepalive=On
ProxyPassReverse ws://localhost:8080/ipython/terminals/websocket/
</Location>
<Location /flow/> 
AuthType basic
AuthName "H2O"
AuthBasicProvider PAM
AuthPAMService httpd
Require valid-user                                                          
ProxyPass        http://localhost:54321/flow/ timeout=86400 keepalive=On    
ProxyPassReverse http://localhost:54321/flow/                               
RequestHeader set Origin "http://localhost:54321"                                     
</Location>
<Location /3/>                                                      
ProxyPass        http://localhost:54321/3/ timeout=86400 keepalive=On    
ProxyPassReverse http://localhost:54321/3/                        
</Location> 
<Location /4/>                                                      
ProxyPass        http://localhost:54321/4/ timeout=86400 keepalive=On    
ProxyPassReverse http://localhost:54321/4/                        
</Location>
<Location /99/>                                                      
ProxyPass        http://localhost:54321/99/ timeout=86400 keepalive=On    
ProxyPassReverse http://localhost:54321/99/                        
</Location> 
<Location /tensorboard/> 
AuthType basic
AuthName "Tensorboard"
AuthBasicProvider PAM
AuthPAMService httpd
Require valid-user                                                          
ProxyPass        http://localhost:6006/ timeout=86400 keepalive=On    
ProxyPassReverse http://localhost:6006/                               
RequestHeader set Origin "http://localhost:6006"                                     
</Location> 
<Location /data/>                                                      
ProxyPass        http://localhost:6006/data/     
ProxyPassReverse http://localhost:6006/data/                         
</Location> 
<Location /lib/>                                                      
ProxyPass        http://localhost:6006/lib/    
ProxyPassReverse http://localhost:6006/lib/                         
</Location>  
<Location /external/>                                                      
ProxyPass        http://localhost:6006/external/   
ProxyPassReverse http://localhost:6006/external/                         
</Location>                                                                       
</VirtualHost>
EOF

chkconfig --level 3 httpd on

cat > /var/www/html/index.html <<EOF
<html><head><title>Unified Data Science Platform</title></head>
<body>
<h1>Unified Data Science Platform</h1>
<p>
Please use your <mark>Your network credentials</mark> to logon to the following three web-accessible services.
<ul>
<li><a href="/ipython/">Jupyter (iPython and iTorch)</a>
<li><a href="/rstudio/">R Studio Server</a>
<li><a href="/shiny/">R Shiny Server</a>
<li><a href="/flow/">H2O Flow</a>
<li><a href="/tensorboard/">Tensorboard</a>
</ul>
</p>
<p>
<h2>Documentation</h2>
<p>
<a href="https://cran.r-project.org/manuals.html">The R Project</a>
</p>
<p>
<a href="https://www.rstudio.com">R Studio Server </a> and <a href="https://shiny.rstudio.com">R Shiny Server</a>
</p>
<p>
<a href="http://jupyter.org">Jupyter</a>
</p>
<p>
<a href="https://docs.python.org/2.7/">Python 2.7</a> and <a href="https://docs.python.org/3.4/">Python 3.4</a>
</p>
<p>
<a href="http://docs.h2o.ai/h2o/latest-stable/index.html">H2O </a>
</p>
<p>
<a href="https://www.tensorflow.org/programmers_guide/summaries_and_tensorboard">Tensorboard </a>
</p>
<p>
<a href="http://torch.ch/docs/getting-started.html#_">Torch</a> and <a href="https://github.com/facebook/iTorch">iTorch</a>
</p>

</body></html>
EOF

rm -f ${WILDCARD_CERTS_ARCHIVE} ${WILDCARD_PUBLIC_CERT} ${WILDCARD_PRIVATE_CERT}

cd $SCRIPT_DIR