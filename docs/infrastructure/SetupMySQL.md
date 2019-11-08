# MySQL RDS
If no RDS is specified, MLiy will use the SQLite database, which is an in-memory database that does not persist across deployments. 

You will want to use a separate MySQL database for production deployments.

## Setting up the MySQL Database
We provide a Cloudformation template for setting up a MySQL database on AWS:

./scripts/AWS_RDS_MLiy_CloudFormation.yaml

Parameters and their defaults can be referenced within template. Make sure that the role responsible for launching the database has the right permissions.


Minimum Cloudformation Parameters:

- DBName: The database name.
- MasterUsername: The database admin account username.
- MasterUserPassword: The database admin account password
- VPCSecurityGroups: The list of VPC security groups that contains instances that need access to the database
- DBSubnetGroupName: A DB subnet group to associate with the DB instance.
- KmsKeyId: The ARN of the AWS Key Management Service (AWS KMS) master key that's used to encrypt the DB instance.
- DBParameterGroupName: The name of an existing DB parameter group.
- OptionGroupName: The option group that this DB instance is associated with.

