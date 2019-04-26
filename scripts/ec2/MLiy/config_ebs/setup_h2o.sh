#!/bin/bash
# Script to setup MLiy
# The script expects environment variables as input

# Copyright 2017 MLiy Contributors

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

APP_NAME="h2o"
LOG_FILE="/var/log/$APP_NAME.log"

touch "$LOG_FILE"
chown analyst:analyst "$LOG_FILE"

read -r -d "" SYSCONFIG <<EOF
export LOG_FILE="$LOG_FILE"
export JAR_FILE="$MLIY_HOME/software/$APP_NAME/$APP_NAME-3.20.0.3/$APP_NAME.jar"
export PID_FILE="/var/run/$APP_NAME.pid"
EOF
echo "$SYSCONFIG" > "/etc/sysconfig/$APP_NAME"

read -r -d "" INITD <<EOF
#!/bin/bash
# chkconfig: 2345 20 80
# description: sysvinit script for $APP_NAME

export PROG="$APP_NAME"

[[ -f "/etc/init.d/functions" ]] && source "/etc/init.d/functions"
[[ -f "/etc/profile.d/mliy.sh" ]] && source "/etc/profile.d/mliy.sh"
[[ -f "/etc/sysconfig/\$PROG" ]] && source "/etc/sysconfig/\$PROG"

start() {
    echo "Starting \$PROG ..."
    if [[ ! -f \$PID_FILE ]]; then
        nohup java -jar \$JAR_FILE >> "\$LOG_FILE" 2>&1 &
        echo \$! > \$PID_FILE
    else
        echo "\$PROG is already running ..."
    fi
}

stop() {
    if [[ -f \$PID_FILE ]]; then
        PID=\$(cat \$PID_FILE);
        echo "\$PROG stoping ..."
        kill \$PID;
        echo "\$PROG stopped ..."
        rm \$PID_FILE
    else
        echo "\$PROG is not running ..."
    fi
}

case "\$1" in
    start)
       start
       ;;
    stop)
       stop
       ;;
    restart)
       stop
       start
       ;;
    status)
       # code to check status of app comes here
       # example: status program_name
       ;;
    *)
       echo "Usage: \$0 {start|stop|status|restart}"
esac

exit 0
EOF

echo "$INITD" > "/etc/init.d/$APP_NAME"
chmod +x "/etc/init.d/$APP_NAME"

chkconfig --add "$APP_NAME"
