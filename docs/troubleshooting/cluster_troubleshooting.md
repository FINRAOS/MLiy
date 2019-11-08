# Cluster Troubleshooting

## Logs

#### Logs on EMR
Assuming the S3 bucket(s) and permissions were configured correctly, logs on EMR can be viewed through the AWS console. Go to EMR > Your Cluster > Steps Tab > Logs. However, these logs will not show if the bootstrap or step fails.


#### Master Node logs
The master node's logs can be viewed through SSH. Follow the instructions on the AWS EMR console > Summary > SSH to access the master node and navigate to /var/logs/. There should be startup logs.

## Common Cluster Problems
Make sure the Params are spelt correctly. 
- Clusters will not launch if there is a missing/misspelled param.

Bootstrap fails
- Check to make sure that the EMR Job Flow Role has the right permissions to the S3 buckets.
- Make sure that each command in the bootstrap script works.

Logs aren't appearing anywhere
- Make sure that the EMR Job Flow Role has the right permissions to the S3 buckets
- Make sure that the path to the log is correct.
- The logs tend to appear later after the cluster's steps are completed. Wait a few minutes and refresh the page.

Cannot connect to the cluster
- If the bootstrap and step completed, check the logs in the AWS EMR console > Steps > View logs.
    - Confirm that the Apache server is running.
- If using Apache, it may not be configured right. Check LDAP configurations (if any) and the EMR cluster on AWS console to make sure that the cluster is running.
    - SSL cert could be expired/non-existant. This could cause the Apache server to fail.

Cluster suddenly terminates
- One of the most common causes is that the cluster is created using SPOT pricing. Try again with ON DEMAND pricing checked in the user interface.

Everything is correct but the cloudformation isn't being created
- If this is the first cluster that is being launched by the MLiy web app, there is a possibility that an AWS client configuration error is taking place.
    - To see if this is the case, SSH into the MLiy web instance's EC2. Check the logs at /home/mliyapp/logs/mliylaunch.log. This specific error is "the region must be set".
    - To fix, restart the server in the mliy webapp instance with "apachectl stop" and "apachectl start".

Cloudformation failed
- Check the cloudformation logs in the AWS console. 
- One possibility is that AWS ran out of that specific instance type for the account.

