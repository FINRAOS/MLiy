# Create a Manager Group
You will need to create a manager group to assign users to. The manager group is defined in the django settings file (settings.py). If you use the simpledb fixture provided with the website and the default settings file the group is created automatically, named manager. Otherwise you will need to create a group with a matching name in the admin view.

If LDAP is used, this manager group will be used to automatically add certain users into the manager group based on their DN.

```
MANAGER_GROUP_NAME = 'my_mliy_manager_group_name'
```