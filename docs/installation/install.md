# MLiy Web Application

MLiy is installed through CloudFormation and will launch an EC2 instance via Auto Scaling Group and Launch Configuration.
The Launch Configuration runs its User Script, which are shell commands to install the application in the EC2 instance once it is ready.

Options:

- ELB: If an ELB name is specified in params.json, it will create an ELB with multi-AZ support
- Route 53: If CreateRoute53ElbCnameRecord is set to TRUE in params.json, it will create a Route 53 Alias record mapping to the ELB created earlier.
- MySQL RDS: If using MySQL for data store, set DatabaseType to mysql and create the mysql database before installing MLiy web application (see the [MySql RDS]) Section).

Checkout the MLiy project from Git. Parameters and default values can be obtained from the Cloudformation template "./scripts/AWS_APP_MLiy_CloudFormation.yaml". To simplify deployment, a [params.json] and [deployment.sh] scripts are provided in the ./scripts folder.
- Set the values for your environment in param.json. Leave optional or unused values blank ""

`scripts/params.json`
```
[	{
		"ParameterKey": "TimeZone",
		"ParameterValue": "TimeZone the application is hosted on"
	},{
		"ParameterKey": "LanguageCode",
		"ParameterValue": "Language Code for the application to use"
	},{
		"ParameterKey": "KeyName",
		"ParameterValue": "The SSH key pair to use"
	},{
		"ParameterKey": "ImageId",
		"ParameterValue": "The AMI (Amazon Machine Image) to use"
	},{
		"ParameterKey": "InstanceType",
		"ParameterValue": "The EC2 instance type to use"
	},{
		"ParameterKey": "IamInstanceProfile",
		"ParameterValue": "The instance profile to use"
	},{
		"ParameterKey": "SecurityGroups",
		"ParameterValue": "Security Groups to associate with Launch Configuration"
	},{
		"ParameterKey": "SourceBucket",
		"ParameterValue": "The source S3 bucket where the installation script is located. Do not prefix with s3://"
	},{
		"ParameterKey": "SourcePackage",
		"ParameterValue": "The name of the installation package"
	},{
		"ParameterKey": "SourceScript",
		"ParameterValue": "The name of the installation script"
	},{
		"ParameterKey": "elbName",
		"ParameterValue": "The name to use for the ELB"
	},{
		"ParameterKey": "elbSubnets",
		"ParameterValue": "The subnets to use for the ELB"
	},{
		"ParameterKey": "elbSecurityGroups",
		"ParameterValue": "The security groups to use for the ELB"
	},{
		"ParameterKey": "elbSSLCertificateId",
		"ParameterValue": "The ARN of the SSL certificate to use. For more information about SSL certificates, see http://docs.aws.amazon.com/IAM/latest/UserGuide/ManagingServerCerts.html in the AWS Identity and Access Management documentation."
	},{
		"ParameterKey": "elbhealthUrl",
		"ParameterValue": "The health check URL to use for the ELB (format: [PROTOCOL]:[PORT]/[PATH])"
	},{
		"ParameterKey": "elbHealthyThreshold",
		"ParameterValue": "The number of consecutive health checks successes required before moving the instance to the Healthy state"
	},{
		"ParameterKey": "elbUnhealthyThreshold",
		"ParameterValue": "The number of consecutive health check failures required before moving the instance to the Unhealthy state"
	},{
		"ParameterKey": "elbInterval",
		"ParameterValue": "The approximate interval, in seconds, between health checks of an individual instance"
	},{
		"ParameterKey": "elbTimeout",
		"ParameterValue": "The amount of time, in seconds, during which no response means a failed health check"
	},{
		"ParameterKey": "asGroupMinSize",
		"ParameterValue": "The min size to use for the autoscaling group"
	},{
		"ParameterKey": "asGroupMaxSize",
		"ParameterValue": "The max size to use for the autoscaling group"
	},{
		"ParameterKey": "asVpcSubnets",
		"ParameterValue": "The subnet(s) to use for the autoscaling group"
	},{
		"ParameterKey": "asCooldown",
		"ParameterValue": "The number of seconds after a scaling activity is completed before any further scaling activities can start."
	},{
		"ParameterKey": "asHealthCheckGracePeriod",
		"ParameterValue": "The length of time in seconds after a new EC2 instance comes into service that Auto Scaling starts checking its health."
	},{
		"ParameterKey": "asHealthCheckType",
		"ParameterValue": "The service you want the health status from, Amazon EC2 or Elastic Load Balancer. Valid values are EC2 or ELB."
	},{
		"ParameterKey": "asMinSuccessfulInstancesPercent",
		"ParameterValue": "Specifies the percentage of instances in an Auto Scaling rolling update that must signal success for an update to succeed."
	},{
		"ParameterKey": "asPauseTime",
		"ParameterValue": "The amount of time that AWS CloudFormation pauses after making a change to a batch of instances to give those instances time to start software applications."
	},{
		"ParameterKey": "signalCount",
		"ParameterValue": "The number of success signals AWS CloudFormation must receive before it sets the resource status as CREATE_COMPLETE"
	},{
		"ParameterKey": "signalTimeout",
		"ParameterValue": "The amount of time to wait before timing out due to not receiving a cfn-signal from instances in the autoscaling group"
	},{
		"ParameterKey": "DjangoSecretKey",
		"ParameterValue": "The secret key for a particular Django installation. This is used to provide cryptographic signing, and should be set to a unique, unpredictable value."
	},{
		"ParameterKey": "LdapAuthUrl",
		"ParameterValue": "Specifies the LDAP server, the base DN, the attribute to use in the search, as well as the extra search filter to use."
	},{
		"ParameterKey": "LdapBindDn",
		"ParameterValue": "A DN to bind with during the search phase."
	},{
		"ParameterKey": "LdapBindPassword",
		"ParameterValue": "Command to run to obtain the password for above user"
	},{
		"ParameterKey": "LdapGroupAttribute",
		"ParameterValue": "Authorize member of this group to access Mliy Web Application"
	},{
		"ParameterKey": "LdapAdminGroupAttribute",
		"ParameterValue": "Authorize member of this group to manage MLiy Web Application"
	},{
		"ParameterKey": "LdapDisableCertValidation",
		"ParameterValue": "Disable SSL certificate validation when connecting to the LDAP server"
	},{
		"ParameterKey": "ManagerHostname",
		"ParameterValue": "The Fully Qualified Hostname of the EC2 instance hosting MLiy web application"
	},{
		"ParameterKey": "DnsService",
		"ParameterValue": "DNS service to use for MLiy-launched instances."
	},{
		"ParameterKey": "DomainName",
		"ParameterValue": "The domain used (eg Route53 Hosted Zone) when managing DNS records"
	},{
		"ParameterKey": "AppDns",
		"ParameterValue": "The Fully Qualified DNS of application that maps to ELB. This is what will be used to access the application"
	},{
		"ParameterKey": "DnsApiUrl",
		"ParameterValue": "The DNS REST API URL to use to register and unregister A record for MLiy instances"
	},{
		"ParameterKey": "DnsMliyDomain",
		"ParameterValue": "The DNS Domain to use to register and unregister A record for MLiy instances"
	},{
		"ParameterKey": "DnsApiData",
		"ParameterValue": "Any Data Payload to send to DNS API REST Services"
	},{
		"ParameterKey": "CreateRoute53ElbCnameRecord",
		"ParameterValue": "Create a DNS CNAME Record AppDns in Route53 hosted zone DomainName that maps to ELB: TRUE or FALSE"
	},{
		"ParameterKey": "DatabaseType",
		"ParameterValue": "The Database Type supporting MLiy web application"
	},{
		"ParameterKey": "DatabaseName",
		"ParameterValue": "If using mysql, provide database name"
	},{
		"ParameterKey": "DatabaseHostname",
		"ParameterValue": "If using mysql, provide database hostname"
	},{
		"ParameterKey": "DatabaseUserName",
		"ParameterValue": "If using mysql, provide database username to connect with"
	},{
		"ParameterKey": "DatabaseUserPassword",
		"ParameterValue": "If using mysql, provide database password of the username to connect with"
	},{
		"ParameterKey": "DatabaseInitialize",
		"ParameterValue": "Initialize specified database with tables and default data. This needs to be TRUE for initial deployment and FALSE for subsequent deployments."
	},{
		"ParameterKey": "ProxyScript",
		"ParameterValue": "The name of the proxy script injected in the scripts folder that set proxy variables in order to download packages"
	}
]
```

- Uncomment and set the following values for your environment in deployment.sh

```
AWS_DEFAULT_REGION="Amazon Region"
STACK_NAME="Unique Cloudformation Stack Name to create"
TAGS="Key Value pairs to tag AWS resource with"
```
- Permissions required for the role which runs the AWS CLI in deployment.sh:
    - launch CloudFormation Stack
    - launch EC2 instances
    - launch AutoScaling Launch Configuration
    - launch AutoScaling Groups
    - Ability to create Route53 record in appropriate zone

### Build

Change directory to the scripts folder  and run the following command to build:
```
cd scripts
bash build.sh
```
MLiy package mliyweb.tar.gz is generated in the ./dist folder. Stage the ./dist/mliyweb.tar.gz file in an S3 location.
This package will be used for installing the MLiy Web Application and the MLiy Image (in the EC2 instances started from the MLiy Web Application).

### Install
We created a simple script for launching the Cloudformation template.

_Deployment Command_
```
cd scripts
bash ./deployment.sh
```

[deployment.sh]:../../scripts/deployment.sh
[params.json]:../../scripts/params.json
[MySQL RDS]:../infrastructure/SetupRDS.md