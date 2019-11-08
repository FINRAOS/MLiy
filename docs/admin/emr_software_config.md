# EMR Software Config
The Software Configuration can be configured to spin up an EMR cluster. Simply check the "EMR config" box in the software configuration, provide the correct cloudformation template, and select the corresponding parameters. 
 
 - Software Configurations can be used for creating either Instances or Clusters, but not both. 
  - If the EMR config box is checked, MLiy will not use any of the parameters in the Instance Configurations area, and the Software Configuration becomes EMR exclusive.

MLiy web application packages includes sample image for Spark cluster in scripts/emr folder:
- AWS_EMR_Spark_MLiy_CloudFormation.json 
- associated bootstrap and step scripts in the scripts/emr folder. 

Place the custom EMR CloudFormation template into the folder scripts/emr and run "python manage.py sync_cf" from inside the EC2 instance hosting the MLiy web application (see [Administrator Commands]). This will make the template selectable in the Django Admin console > Software Config.

[Administrator Commands]:../installation/commands.md