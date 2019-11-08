# Prerequisites

- AWS Account with subnets in a VPC
- Knowledge of how to launch EC2, CloudFormation, ELB and RDS resources in AWS
- The ability to SSH into the MLiy Web Application's EC2 instance

## ACM
- SSL Certificate for MLiy website and wildcard certificate for application domain.

## IAM
- An IAM instance profile for MLiy EC2 instance with ability to manage EC2, EBS, Cloudformation Stack, read access to the S3 bucket containing the MLiy package, and pass role permission to IAM role for MLiy
- An IAM instance profile for MLiy with encrypt/decrypt access to KMS keys and read/write access to S3 buckets
- An IAM role to use create and manage resources. Resources with * means that they might not be be created, and are therefore optional:
  - CloudFormation
  - EC2
  - EBS
  - Auto Scaling Launch Configuration
  - Auto Scaling Group
  - Elastic Load Balancer*
  - RDS DBInstance
  - Route 53*
  - EMR
  - IAM: Instance Profiles
  - SSM

## S3
- S3 Bucket(s)
    - Bucket to store bootstrap scripts and step scripts. Unlike EC2 user_data scripts which can be coded into the Cloudformation template, EMR has to reference the buckets for these scripts to run find and run them. When deploying the MLiy web app, deploy the scripts separately to an S3 bucket. Sample scripts are included in the project in scripts/emr/spark
    - Bucket to store logs of the EMR cluster.
    - Bucket to store the MLiy package
    - *NOTE*: These can all be the same bucket


## Security Groups

| Security Group | Inbound                                    | Outbound                                     |
| ---            | ---                                        | ---                                          |
| MLiy-elb       | HTTPS port 443 from allowed networks       | HTTPS port 443 to MLiy-web                   |
|                | MLiy-ec2                                   |                                              |
| MLiy-web       | SSH 22 from allowed networks               | MySQL port 3306 on MLiy-db                   |
|                | MLiy-ec2 (if no ELB)                       | LDAP Server port 636                         |
|                | HTTPS port 443 from MLiy-elb (if ELB)      |                                              |
| MLiy-ec2       | SSH port 22 from allowed networks          | MLiy-web port 443                            |
|                | HTTPS port 443 from allowed networks       | Other*                                       |
| MLiy-rds       | MySQL port 3306 from MLiy-web              | No Outbound                                  |
|emr-master      |TCP UDP port 0-65535 from ```emr-master```  | All traffic                                  |
|                |TCP UDP port 0-65535 from ```emr-slave```    | All traffic to emr-master                    |
|                |IPv4 from ```emr-master```                  | All traffic to emr-slave                     |
|                |IPv4 from ```emr-slave```                   |                                              |
|emr-slave       |TCP UDP port 0-65535 from ```emr-master```  | All traffic                                  |
|                |TCP UDP port 0-65535 from ```emr-slave```    | All traffic to emr-master                    |
|                |IPv4 from ```emr-master```                  | All traffic to emr-slave                     |
|                |IPv4 from ```emr-slave```                   |                                              |

*to the internet, proxy, data services, internal network, etc.

<hr>
<hr>

## LDAP
- Active Directory (AD) listening on LDAPS. OpenLDAP with memberOf overlay is supported (see section [Support for OpenLDAP]) .
- An LDAP account to be configured as a service account in order to verify group authorization