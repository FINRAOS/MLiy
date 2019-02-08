# Support for OpenLDAP
Please note that text in two brackets [[[your_input]]] expects you to provide appropriate value.

[Setup OpenLDAP Server](#setup-openldap-server)
- [Installation and Configuration](#installation-and-configuration)
- [Enable memberOf Overlay](#enable-memberof-overlay)
- [Setup Sample Users and Groups](#setup-sample-users-and-groups)
- [Enable SSL](#enable-ssl)

[MLiy Web application and openLDAP](#mliy-web-application-and-openldap)

[MLiy Image and openLDAP](#mliy-image-and-openldap)

## Setup OpenLDAP Server
### Installation and Configuration
You can skip this section if you already have OpenLDAP server in place.
In Amazon Linux, as root, run the following yum command to install openLDAP:
```
[root]# yum -y install openldap openldap-servers openldap-clients openldap-devel
```
Generate a password hash to be used as the admin password.
```
[root]#slappasswd
New password:[[Your_Password]]
Re-enter new password:[[Your_Password]]
{SSHA}Vq2iFfggZoiBUnQFIjEE4npeJLdzuJZC
```

Add the admin user and the admin user's password hash to the OpenLDAP configuration in the olcDatabase={2}bdb.ldif file. If the olcRootPW attribute does not already exist, create it. Then set the value to be the hash you created from slappasswd. Also update the olcSuffix to match your DNS domain name.
```
[root]# cd /etc/openldap/slapd.d/cn\=config
```

`vi olcDatabase\=\{2\}bdb.ldif`:
```
olcSuffix: dc=example,dc=com
...
olcRootDN: cn=Manager,dc=example,dc=com
...
olcRootPW: {SSHA}Vq2iFfggZoiBUnQFIjEE4npeJLdzuJZC
...
```
Modify the DN of the admin user in the olcDatabase={1}monitor.ldif file to match the olcRootDN line in the olcDatabase={2}bdb.ldif file.

`vi olcDatabase\=\{1\}monitor.ldif`:
```
olcAccess: {0}to *  by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read  by dn.base="cn=manager,dc=example,dc=com" read  by * none
```
Add the following two lines to the end of the file to restrict users from viewing other users' password hashes.

`vi olcDatabase\=\{2\}bdb.ldif`:
```
olcAccess: {0}to attrs=userPassword by self write by dn.base="cn=Manager,dc=example,dc=com" write by anonymous auth by * none
olcAccess: {1}to * by dn.base="cn=Manager,dc=example,dc=com" write by self write by * read
```
Configure openLDAP for automatic restart on system startup and startup openLDAP.
```
[root]# chkconfig slapd on
[root]# service slapd start
```
Add the entries for domain and Organizational Unit (OU), users and groups.
```
[root]# cd
[root]# cat > example.ldif <<EOF

dn: dc=example,dc=com
objectClass: dcObject
objectClass: organization
dc: example
o : example

dn: ou=users,dc=example,dc=com
objectClass: organizationalUnit
ou: users

dn: ou=groups,dc=example,dc=com
objectClass: organizationalUnit
ou: groups

EOF

[root]# ldapadd -f example.ldif -D cn=Manager,dc=example,dc=com -w [[Your_Password]]
```
Verify that the entries were added correctly.
```
[root]# ldapsearch -x -LLL -b dc=example,dc=com

dn: dc=example,dc=com
objectClass: dcObject
objectClass: organization
dc: example
o: example

dn: ou=groups,dc=example,dc=com
objectClass: organizationalUnit
ou: Groups

dn: ou=users,dc=example,dc=com
objectClass: organizationalUnit
ou: users
```

### Enable memberOf Overlay
Both the MLiy web application and the MLiy image uses the memberOf attribute of a user to verify during authentication whether the user is member of an authorized group. Every group created before memberOf overlay is enabled has to be deleted and recreated in order for these changes to take effect. LDAP assigns a "member" attribute behind the scenes to existing users when creating a group. For existing openLDAP implementation, we recommend creating new groups for MLiy users.

You need to find out what backend databases you have configured. The one you're looking for could be BDB, HDB or MDB. In our case, it is BDB below.
```
[root]# ldapsearch -H ldapi:/// -Y EXTERNAL -b "cn=config" -LLL -Q "olcDatabase=*" dn

dn: olcDatabase={-1}frontend,cn=config

dn: olcDatabase={0}config,cn=config

dn: olcDatabase={1}monitor,cn=config

dn: olcDatabase={2}bdb,cn=config

dn: olcOverlay={0}memberof,olcDatabase={2}bdb,cn=config

dn: olcOverlay={1}refint,olcDatabase={2}bdb,cn=config
```

Set up the memberOf module and configuring referential integrity:
```
[root]# cat >  memberOfmodule.ldif <<EOF

dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: memberof.la

EOF

[root]# ldapadd -Q -Y EXTERNAL -H ldapi:/// -f memberOfmodule.ldif

[root]# cat > memberof_config.ldif <<EOF

dn: olcOverlay=memberof,olcDatabase={2}bdb,cn=config
changetype: add
objectClass: olcConfig
objectClass: olcMemberOf
objectClass: olcOverlayConfig
objectClass: top
olcOverlay: memberof
olcMemberOfDangling: ignore
olcMemberOfRefInt: TRUE
olcMemberOfGroupOC: groupOfNames
olcMemberOfMemberAD: member
olcMemberOfMemberOfAD: memberOf

EOF

[root]# ldapadd -Q -Y EXTERNAL -H ldapi:/// -f memberOfconfig.ldif
```
Load and configure the refint module:
```
[root]# cat > refintmod.ldif <<EOF

dn: cn=module{0},cn=config
add: olcmoduleload
olcmoduleload: refint

EOF

[root]# ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f refintmod.ldif

[root]# cat > refintconfig.ldif <<EOF

dn: olcOverlay=refint,olcDatabase={2}bdb,cn=config
objectClass: olcConfig
objectClass: olcOverlayConfig
objectClass: olcRefintConfig
objectClass: top
olcOverlay: refint
olcRefintAttribute: memberof member manager owner

EOF

ldapadd -Q -Y EXTERNAL -H ldapi:/// -f refintconfig.ldif
```

### Setup Sample Users and Groups
Use the following command to generate hash for each user's password:
```
[root]# slappasswd -h {SHA} -s [[Your_Password]]
{SSHA}Vq2iFfggZoiBUnQFIjEE4npeJLdzuJZC
```

Create the service or application account. The account will used to query LDAP during authentication.
```
[root]# cd
[root]# cat > service_user.ldif<<EOF

dn: cn=Service User,ou=Users,dc=example,dc=com
objectClass: top
objectClass: posixAccount
objectClass: shadowAccount
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
cn: Service User
givenName: Service
sn: User
uid: svcuser
uidNumber: 1000
gidNumber: 100
homeDirectory: /home/svcuser
mail: svcuser@[[Your_Domain]]
loginShell: /bin/bash
userPassword: {SSHA}Vq2iFfggZoiBUnQFIjEE4npeJLdzuJZC

EOF

[root]# ldapadd -f service_user.ldif -D cn=Manager,dc=example,dc=com -w [[Your_Password]]
```

Create a sample MLiy user to test access and usage with.
```
[root]# cat > mliy_user.ldif<<EOF

dn: cn=Mliy User,ou=Users,dc=example,dc=com
objectClass: top
objectClass: posixAccount
objectClass: shadowAccount
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
cn: Mliy User
givenName: Mliy
sn: User
uid: mliyuser
uidNumber: 1001
gidNumber:101
homeDirectory: /home/mliyuser
mail: mliyuser@[[Your_Domain]]
loginShell: /bin/bash
userPassword: {SSHA}Vq2iFfggZoiBUnQFIjEE4npeJLdzuJZC

EOF

[root]# ldapadd -f mliy_user.ldif -D cn=Manager,dc=example,dc=com -w [[Your_Password]]
```

Create another user to test no access to MLiy.
```
[root]# cat > test_user.ldif<<EOF

dn: cn=Test User,ou=Users,dc=example,dc=com
objectClass: top
objectClass: posixAccount
objectClass: shadowAccount
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
cn: Test User
givenName: Test
sn: User
uid: testuser
uidNumber: 1002
gidNumber:101
homeDirectory: /home/testuser
mail: testuser@[[Your_Domain]]
loginShell: /bin/bash
userPassword: {SSHA}Vq2iFfggZoiBUnQFIjEE4npeJLdzuJZC

EOF

[root]# ldapadd -f test_user.ldif -D cn=Manager,dc=example,dc=com -w [[Your_Password]]
```

Create a group for users authorized to access MLiy:
```
[root]# cat > mliygroup.ldif<<EOF

dn: cn=mliyusers,ou=Groups,dc=example,dc=com
objectClass: groupofnames
cn: mliyusers
description: All MLiy users
member: cn=Mliy User,ou=Users,dc=example,dc=com

EOF

[root]# ldapadd -f mliygroup.ldif -D cn=Manager,dc=example,dc=com -w [[Your_Password]]
```

Verify that users is a member of the MLiy user's group:
```
[root]# ldapsearch -x -LLL -H ldap:/// -b "cn=Mliy User,ou=Users,dc=example,dc=com" dn memberof
dn: cn=Mliy User,ou=users,dc=example,dc=com
memberOf: cn=mliyusers,ou=Groups,dc=example,dc=com
```

### Enable SSL
Copy your signed public SSL cert and private key and cert store to /etc/openldap/certs/ and change the owner to user ldap:
```
[root]# cp [[Your_Public_Signed_Cert]].crt /etc/openldap/certs/
[root]# cp [[{]]Your_Private_key]].key /etc/openldap/certs/
[root]# cp /etc/pki/tls/certs/ca-bundle.crt /etc/openldap/certs/

[root]# chown ldap. /etc/openldap/certs/{Your_Private_key}.key /etc/openldap/certs/[[Your_Public_Signed_Cert]].crt /etc/openldap/certs/ca-bundle.crt
```
Create and execute the following config:
```
[root]# cat > mod_ssl.ldif <<EOF

dn: cn=config
changetype: modify
add: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/openldap/certs/ca-bundle.crt
-
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/openldap/certs/{Your_Public_Signed_Cert}.crt
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/openldap/certs/[[Your_Private_key]].key
EOF

[root]# ldapmodify -Y EXTERNAL -H ldapi:/// -f mod_ssl.ldif

SASL/EXTERNAL authentication started
SASL username: gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth
SASL SSF: 0
modifying entry "cn=config"
```

Change the LDAP configuration to use LDAPS:
```
[root]# vi /etc/sysconfig/ldap:

SLAPD_LDAPS=yes

[root]# service slapd restart

Stopping slapd:                    [  OK  ]
Starting slapd:                    [  OK  ]
```

If using Self-signed cert, make the following change in LDAP clients:
```
echo "TLS_REQCERT allow" >> /etc/openldap/ldap.conf
```

Finally, test LDAPS:
```
ldapsearch -v -x -LLL -b dc=example,dc=com -ZZ
ldapsearch -v -x -LLL -H ldaps://localhost -b dc=example,dc=com
```

## MLiy Web application and openLDAP

The value of AuthLDAPURL will be similar to ldaps://*Your_LDAP_HOST_NAME*/ou=Users,*Your_Domain*?uid,cn,sn,givenName,mail
See http://httpd.apache.org/docs/current/mod/mod_authnz_ldap.html on how to make your LDAP server work with MLiy Web application. Here is sample configuration that works with the sample OpenLDAP setup provided here:

`/etc/httpd/conf.d/mliyweb.conf`:
```
<Location />
  AuthType Basic
  AuthBasicProvider ldap
  AuthName "LDAP Authentication"
  AuthLDAPURL "ldaps://[[Your_LDAP_HOST_NAME]]/ou=Users,dc=example,dc=com?uid,cn,sn,givenName,mail"
  AuthLDAPBindDN "cn=Service User,ou=Users,dc=example,dc=com"
  AuthLDAPBindPassword "[[Your_password]]"
  AuthLDAPGroupAttribute member
  Require ldap-attribute memberOf="cn=mliyusers,ou=Groups,dc=example,dc=com"
</Location>
```

If your LDAP server does not have valid SSL certificate, you may temporarily disable certificate verification by uncommenting #LDAPVerifyServerCert Off in /etc/httpd/conf.d/mliyweb.conf or in source scripts/install.sh, build, stage and deploy. We highly recommended that you use valid SSL certificates.

## MLiy Image and openLDAP

In Admin interface of MLiy application, create a parameter key LDAP_TYPE with value openLDAP. Use this parameter in Software Configuration of this MLiy image. See https://arthurdejong.org/nss-pam-ldapd/docs on how to make nss-pam-ldapd package work with your LDAP server. Here is sample configuration that works with the sample OpenLDAP setup provided here:

`/etc/nslcd.conf`:
```
uid nslcd
gid nslcd
ldap_version 3
uri ldaps://[[Your_LDAP_HOST_NAME]]/
ignorecase yes
base dc=example,dc=com
binddn cn=Service User,ou=Users,dc=example,dc=com
bindpw [[Your_password]]
ssl no
tls_reqcert hard
tls_cacertfile /etc/ssl/certs/ca-bundle.crt
pagesize 1000
bind_timelimit 30
timelimit 30
scope sub
referrals no

filter passwd (&(objectClass=person)(memberOf=cn=mliyusers,ou=Groups,dc=example,dc=com))
map    passwd gecos            displayName
map    passwd loginShell       "/bin/bash"
map    passwd homeDirectory    "/ext/home/analyst"
map    passwd gidNumber        "10001"
filter shadow (&(objectClass=person)(memberOf=cn=mliyusers,ou=Groups,dc=example,dc=com))
filter group  (objectClass=groupOfNames)
```

`/etc/pam_ldap.conf`:
```
ldap_version 3
uri ldaps://[[Your_LDAP_HOST_NAME]]/
base dc=example,dc=com
binddn cn=Service User,ou=Users,dc=example,dc=com
bindpw [[Your_password]]
ssl no
tls_reqcert hard
tls_cacertfile /etc/ssl/certs/ca-bundle.crt
bind_timelimit 30
scope sub
referrals no
pam_login_attribute uid
pam_filter objectClass=person
```

If your LDAP server does not have valid SSL certificate, you may temporarily disable certificate verification by changing "tls_reqcert hard" to "tls_reqcert allow" in either the instance ( update /etc/nslcd.conf and /etc/pam_ldap.conf and restart nslcd) or change source scripts/ec2/MLiy/setup_ldap.sh, build, stage and deploy. We highly recommended that you use valid SSL certificates.
