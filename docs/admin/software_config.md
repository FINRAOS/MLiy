# Software Config

The Software Config is the configuration for instances spun up by MLiy. Group Configs and Software Configs share a many-to-many relationship. 

Software and hardware configurations specific to the resource should be set here, such as the AMI, Cloudformation template, and the User Data (essentialy a script payload) to be used by the resource. 
- Note that not every field is absolutely required. This is because many things can be hard-coded within the Cloudformation template. However, for the sake of reuse and ability to share the same configuration across multiple groups, making use of the Software Config is highly recommended. 

<hr>

Click on the Home link on the top left corner and click on Software Configs and add one or more software configuration. 

- Give the software config a name. 
- Specify the version of MLiy in the Version. This can be found in the file called "version" and is used to specify the S3 location of the artifact.
- Select the respective cloudformation template for the resource.
- Select paramters from the list to be used for the software config.
- Set the instance name in the software config. 

<img src="../img/add_software_config.png" width="800" border="10" />

Associate the groups/group configurations permitted to use this software configuration. 
- Describe the software configuration in HTML format; users will see text when launching this software configuration. 
- Specify the default instance name launched with this software configuration if none is provided in the group configuration. 

There are two hidden fields that are for instances and EMR clusters respectively. 

<img src="../img/permitted_groups.png" width="800" border="10" />

<hr>

The instance specific configurations.
- User Data is essentially the bootstrap script to be run once the EC2 instance is spun up.
- Select AMI to use from AWS.
- Check "Has Progress Bar" to show the progress bar to the user as the EC2 instance comes up. 
- Set the "Addtl volume KMS key" to specify that the volume that comes with the EC2 instance should be encrypted.
- "Addtl volume default size" can be used to set the sizze of the attached volume.
- "Addtl vol description" can be used to describe/notate the volume.

<img src="../img/storage_and_kms.png" width="800" border="10" />

### Cluster Specific Parameters

The EMR master, slave, and additional security groups for master and worker nodes can be set here.

In the "Custom url format" section, the admin can customize the connection to the master node. The text "{{{ URL }}}" will be replaced with the IP address or DNS name. For example, if a Hive cluster is meant to be connected through JDBC, it can be specified here with "jdbc:hive://{{{ URL }}}:10001". This will be displayed as "jdbc:hive//10.20.30.40:10000" (or "jdbc:hive://your_hive_url:10000" if a DNS name is provided) once the cluster is created.

If left blank, or if the text doesn't contain "{{{ URL }}}", it will default to the IP (or DNS name if provided).

<img src="../img/emr_configs.png" width="800" border="10" />