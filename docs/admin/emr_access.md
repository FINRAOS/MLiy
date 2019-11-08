# Giving Users Cluster Access
To give the user access to launching clusters, they must be in a Group that has an associated Group Config with a cluster Software Config.
Group (has a) Group Config (has a) Cluster Software Configuration.

In Software Config: Select Group Config(s) and check the "Emr config" box.

<img src="../img/cluster_choose_group_config.png" width="" border="10" />

In Group Config: Associate Group with Group Config

<img src="../img/cluster_group_configs.png" width="" border="10" />

Check the box at the top of Group Config to give any users in that Group access to EMR clusters

<img src="../img/group_config_emr_access.png" width="" border="10" />


In Users: Add the user to the Group that has the Cluster Software Config

<img src="../img/cluster_users_add_group.png" width="800" border="10" />

The user should now have access to launching clusters.