# Configuring the Spark Cluster
MLiy comes with a sample Cloudformation template, AWS_EMR_Spark_MLiy_CloudFormation.json, and scripts to setup a Spark cluster.
The sample does the following:
- Configures an Apache server
  - Uses LDAP for authentication and authorization
  - Uses SSL certificates from an S3 bucket
- Configures Jupyter Hub
  - Uses LDAP for authentication and authorization
  - Uses s3 bucket to store jupyterhub notebooks
- Pulls bootstrap.sh and step.sh scripts from S3 buckets
- Contains a landing page on the master node to applications installed on the cluster

### Spark Cluster Parameters

EMR and Spark parameters must be set via custom parameters in the Params table.

Parameters to set:

| Parameter Key             | Description of Value
|---                        |---
| paramInstallBucket        | S3 bucket base bucket where the bootsrap, step, and certificate is located. e.g. mliy-bucket
| paramBootstrapScript      | S3 bucket 'path' of the cluter's bootstrap script. e.g. /my/path/to/bootstrap.sh
| paramStepScript           | S3 bucket 'path' of the cluster's step script. e.g. /my/path/to/step.sh
| paramCertFile             | S3 bucket 'path' of SSL certificates. e.g. /my/path/to/certs.tar.gz
| paramJupyterBucket        | S3 Bucket to store user home folders and Jupyter notebooks
| paramYumServerPort	      | Port of the custom yum server
| paramYumServerHost	      | Custom yum server host
| paramYumServerPrefix      | Any special prefix associated with the yum server
| paramAWSProxyPort	        | Proxy port if using a proxy
| paramAWSProxyHost	        | Proxy host if using a proxy
| paramLdapGroupRdn	        | LDAP group relative distinguished name
| paramLdapGroup	          | LDAP group
| paramLdapSvcUser	        | LDAP service user
| paramLdapSvcRdn           | LDAP service relative distinguished name
| paramLdapUserRdn          | LDAP user relative distinguished name
| paramLdapBaseDn	          | LDAP based distinguished name
| paramLdapIp	              | IP of the LDAP  server
| paramLdapFqdn	            | LDAP fully qualified distinguished name
| paramYarnLogURI	          | Bucket to store Yarn logs
| paramLogURI	              | Bucket to store EMR logs
| paramSecurityConfiguration| Security configuration of the EMR cluster. See https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-specify-security-configuration.html
| paramServiceRole	        | IAM service role that EMR assumes to access AWS resources
| paramJobFlowRole	        | IAM role that each EC2 instance in the cluster assumes
| paramInstallSecretsCMD    | Command to install a client that can retrieve LDAP password, such as credstash
| paramRunSecretsCMD        | Command to run a client that can retrieve LDAP password, such as credstash.
| paramJupyterBucket        | Bucket containing user home folders and Jupyter notebooks
| paramSsmDocument          | Name of the AWS SSM Document allowing download of jar/zip file to EMR nodes

After all the parameters are set, launch the cluster as a user. See [User Guide].

Once the cluster is started, the user should be able to log in and view a landing page for Jupyter Hub with links to applications. See [Cluster Guide]
