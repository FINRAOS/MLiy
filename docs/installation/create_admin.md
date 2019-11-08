# Create an Admin User
If LDAP is set up and the LDAP LdapAdminGroupAttribute is specified, the Admin can be auto-created/added and this step may not be needed. 

By default, Django provides a login page for the Admin console. However, if the "is_staff=True" is set, this step can be bypassed. Setting "is_admin=True" also gives users admin status and access to all the features of the Django admin console. 

See the example plugin in ldapplugin/ldapauth.py for how "is_staff" and "is_admin" can be automatically set through LDAP. These can also set be through the Django Admin console once the user gets access to it.

In order to access the Django Admin Console without LDAP, create a superuser. Logon to MLiy instance using the SSH Key-pair and sudo to mliyapp user and change to mliyweb directory:
```
sudo su ??? mliyapp
cd mliyweb
```
Activate the Python virtual environment:
```
source ../mliy-python/bin/activate
```
Run the following command to create an admin user:
```
python manage.py createsuperuser
```
You will be prompted to enter a username, email address and associated password. Please keep the credentials in a safe location.

You should now be able to open the MLiy website in a browser, click on "Log in to My Dashboard" on the top right corner, and logon with administrative credentials.

<hr>

# Set Through Cloudformation
If LDAP is set up and connected to the instance, the Admin can be specified through settings.py. Simply place the Admin's AD group into the parameter "LDAP_ADMIN_GROUP_ATTRIBUTE" using the full DN.

If the user is in the admin group, this will automatically add them as an Admin, giving them full access to the site as well as the Django Admin console. 