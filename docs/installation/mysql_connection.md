# Setup MySQL RDS Connection
If the default sqllite database needs to be replaced with mysql without a new MLiy web application deployment, make the following changes on the EC2 instance:

1. On the MLiy web application server, set DB_TYPE to mysql and replace {{{}}} with appropriate values for your MySQL Database in ~mliyapp/mliyweb/mliyweb/settings.py file as user mliyapp:

```
DB_TYPE = 'mysql'

MYSQLDB = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME' : '{{{db_name}}}',
        'HOST' : '{{{db_host}}}',
        'PORT' : '3306',
        'USER' : '{{{db_user}}}',
        'PASSWORD' : '{{{db_passwd}}}',
        'OPTIONS' : {
                'charset' : 'utf8',
                'ssl': {'ca': '/etc/aws-rds/ssl/rds-combined-ca-bundle.pem'},
        }
    }
}
```

2. Go to the ~mliyapp/mliyweb folder and run the following commands to create the models in your MySQL RDS:
```
source ../mliy-python/bin/activate
python manage.py makemigrations
python manage.py migrate
python manage.py sync_cf
```
3. Restart apache as root:
```
apachectl stop
apachectl start
```
