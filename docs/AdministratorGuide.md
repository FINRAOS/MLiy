# MLiy Open Source Administrator Guide


## Installation

#### Software Installation
- [Prerequisites](infrastructure/prerequisites.md)
- [Installation Steps](installation/install.md)
- [MySql Connection](installation/mysql_connection.md)

#### Post Installation
Configuration steps to take after the website is installed.
- [Create Admin](installation/create_admin.md)
  - May not be needed if LDAP is set up to allow certain groups to come through.
  - If the LDAP server and connection is set up, it can allow certain groups to be auto-added as administrators.
  - Requires SSH access to the EC2 instance
- [Set Manager Group](installation/manager_group.md)
  - This is different from the Admin, as it designates a "manager user" and not the site administrator.
  - This can also be set through a parameter in the MLiy Website Cloudformation template.
- [Admin Terminal Commands](installation/commands.md)
  - Django provides many commands to do database and setup actions
  - We provide some custom commands to sync the database's Cloudformation templates with what's on S3.

## Admin Console: Initial Setup and Ongoing Maintenance
Before you are able to launch and start using MLiy instances, you will need to create and register (see [Prerequisites](infrastructure/prerequisites.md)) some AWS resources.  Logon to MLiy Admin console using the URL https://dns_entry_for_mliy_with_ssl_cert/admin. You will see a screen similar to the following:

<img src="./img/site_administration.png" width="800" border="10" />

Set up instance, EMR, and user configurations through the built-in Django Admin console. These are ordered in a way that reduces backtracking between dependencies. 
- [User](admin/user.md)
- [Group](admin/groups.md)
- [Security Groups](admin/security_group.md)
- [Instance Types](admin/instance_type.md)
- [Group Config](admin/group_config.md)
- [Parameters](admin/parameters.md)
- [Software Config](admin/software_config.md)
- [EMR: Granting Access](admin/emr_access.md)
- [EMR: Setting Parameters](admin/emr_parameters.md)
- [EMR: Software Config](admin/emr_software_config.md)

## Sample Created Resources
We provide some sample resources so that they don't have to be made from scratch.

### EC2 Instance
- [Sample EC2 Instance Image](sample_aws_resources/MLiyImageGuide.md)

### Spark Cluster
- [Setting up the sample cluster](sample_aws_resources/cluster_troubleshooting.md)
- [Sample Spark Cluster](sample_aws_resources/MLiyClusterGuide.md)

### AWS Systems Manager Document
MLiy instances and clusters include a iPython custom magic, MliyMagic, which can be used to deploy application jars or zips to Spark classpath in all already running EMR nodes. The library uses AWS Systems Manager Run Command to remotely and securely manage the configuration of your managed instances. The EC2 Instance profile (IAM Role) used to launch the MLiy instance and cluster must be able to invoke SSM Documents and read the specified library file in S3 bucket.


# Django Administrator Documentation

Additional information about administrering the django site, including the user auth module can be found at

https://docs.djangoproject.com/en/2.1/ref/contrib/admin/

and on the MLiy site at the relative url

/admin/doc

[Support for OpenLDAP]:./infrastructure/SupportForOpenLdap.md
[config.sh]:../scripts/config.sh
[deployment.sh]:../scripts/deployment.sh
[User Guide]:./UserGuide.md
[Cluster Developer Guide]:./ClusterDeveloperGuide.md
