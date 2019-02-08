# Simple Instance Pricing Module

Basically the code rips through the pricing json, on demand, whenever it is queried. Caching
is handled by the host OS; it's unlikely that an active caching strategy will be worth the
work during the current workload the system hosting this experiences.

This implementation precedes the AWS pricing service, and depends on a simpler data source, 

## Refreshing the Data

This is super-simple, we use the format from www.ec2instances.info:

	curl http://www.ec2instances.info/instances.json > instances.json

Replace the instances.json file in the instances directory, and it all should work, unless the format has changed.
