#!/bin/bash
#
#    .   ____          _            __ _ _
#   /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
#  ( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
#   \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
#    '  |____| .__|_| |_|_| |_\__, | / / / /
#   =========|_|==============|___/=/_/_/_/
#   :: Spring Boot Startup Script ::
#

### BEGIN INIT INFO
# Provides:          @project.artifactId@
# Required-Start:    $remote_fs $syslog $network
# Required-Stop:     $remote_fs $syslog $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: @project.artifactId@
# Description:       @project.artifactId@
# chkconfig:         2345 99 01
# modification by:   Kola 6089555
### END INIT INFO

[[ -n "$DEBUG" ]] && set -x
SERVICE_NAME=@project.artifactId@
APPLICATION_NAME=`echo  $SERVICE_NAME | tr '[a-z]' '[A-Z]'`
## Adjust log dir if necessary
LOG_DIR=/data/logs/"$SERVICE_NAME"
## Configure whether the default log is turned on
AUTOLOG=false
## Adjust memory settings if necessary
DEV_JVM="-Xms1024m -Xmx1024m -Xss256k -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=256m -XX:NewSize=768m -XX:MaxNewSize=768m -XX:SurvivorRatio=8"
FAT_JVM="-Xms1024m -Xmx1024m -Xss256k -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=256m -XX:NewSize=768m -XX:MaxNewSize=768m -XX:SurvivorRatio=8"
UAT_JVM="-Xms2560m -Xmx2560m -Xss256k -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=384m -XX:NewSize=1536m -XX:MaxNewSize=1536m -XX:SurvivorRatio=8"
PRE_JVM="-Xms2560m -Xmx2560m -Xss256k -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=384m -XX:NewSize=1536m -XX:MaxNewSize=1536m -XX:SurvivorRatio=8"
PROD_JVM="-Xms2560m -Xmx2560m -Xss256k -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=384m -XX:NewSize=1536m -XX:MaxNewSize=1536m -XX:SurvivorRatio=8"

## Only uncomment the following when you are using server jvm
#export JAVA_OPTS="$JAVA_OPTS -server -XX:-ReduceInitialCardMarks"
export JAVA_OPTS="$JAVA_OPTS -Duser.timezone=Asia/Shanghai -Dclient.encoding.override=UTF-8 -Dfile.encoding=UTF-8 -Djava.security.egd=file:/dev/./urandom"
#export JAVA_OPTS="$JAVA_OPTS -Dlogging.file=$LOG_DIR/$SERVICE_NAME.log "
if [[ -e "/opt/app/skywalking/agent/skywalking-agent.jar" ]];then
  export JAVA_OPTS="$JAVA_OPTS -javaagent:/opt/app/skywalking/agent/skywalking-agent.jar -Dskywalking.agent.application_code=@project.artifactId@"
fi
# ENV Initialize
BOOTADMIN_URL=http://ops.dev.blockdata.kyhub.cn/notifications/filters
initEnv() {
  [[ -e "env.dat" ]] && env=`echo  $(cat env.dat) | awk '{print $1}' | tr '[a-z]' '[A-Z]'`
  if [[ -n "$env" ]]; then
    if [[ $env == "PROD" ]]; then
      export ENV=PRO
      BOOTADMIN_URL=http://ops.blockdata.kyhub.cn/notifications/filters
    elif [[ $env == "DEV" ]]; then
      export ENV=DEV
      BOOTADMIN_URL=http://ops.dev.blockdata.kyhub.cn/notifications/filters
    elif [[ $env == "FAT1" ]]; then
      export ENV=DEV && export IDC=$env
      BOOTADMIN_URL=http://ops.fat1.blockdata.kyhub.cn/notifications/filters
    else
      export ENV=DEV && export IDC=$env
    fi

  else
    export ENV=PRO
  fi
  export JAVA_OPTS="$JAVA_OPTS "`eval echo '$'"$env"_JVM`
}

# Initialize variables that cannot be provided by a .conf file
WORKING_DIR="$(pwd)"
# Follow symlinks to find the real jar and detect init.d script
cd "$(dirname "$0")" && cd ../ || exit 1
# shellcheck disable=SC2153
JARFILE="$SERVICE_NAME.jar"
APP_NAME="$SERVICE_NAME"
[[ -n "$JARFILE" ]] && jarfile="$JARFILE"
[[ -n "$APP_NAME" ]] && identity="$APP_NAME"

# ENV Initialize start
initEnv
#[[ -e "env.dat" ]] && env=`echo  $(cat env.dat) | awk '{print $1}' | tr '[a-z]' '[A-Z]'` && export ENV=$env && export JAVA_OPTS="$JAVA_OPTS "`eval echo '$'"$ENV"_JVM`
# ENV Initialize end

[[ -z "$jarfile" ]] && jarfile=$(pwd)/$(basename "$0")
while [[ -L "$jarfile" ]]; do
  if [[ "$jarfile" =~ init\.d ]]; then
    init_script=$(basename "$jarfile")
  else
    configfile="${jarfile%.*}.conf"
    # shellcheck source=/dev/null
    [[ -r ${configfile} ]] && source "${configfile}"
  fi
  jarfile=$(readlink "$jarfile")
  cd "$(dirname "$jarfile")" || exit 1
  jarfile=$(pwd)/$(basename "$jarfile")
done
jarfolder="$( (cd "$(dirname "$jarfile")" && pwd -P) )"
cd "$WORKING_DIR" || exit 1

# Inline script specified in build properties


# Source any config file
configfile="$(basename "app.conf")"

# Initialize CONF_FOLDER location defaulting to jarfolder
[[ -z "$CONF_FOLDER" ]] && CONF_FOLDER="${jarfolder}/config"
# shellcheck source=/dev/null
[[ -r "${CONF_FOLDER}/${configfile}" ]] && source "${CONF_FOLDER}/${configfile}"

# Initialize PID/LOG locations if they weren't provided by the config file
[[ -z "$PID_FOLDER" ]] && PID_FOLDER="/var/run"
[[ -z "$LOG_FOLDER" ]] && LOG_FOLDER="/var/log"
! [[ "$PID_FOLDER" == /* ]] && PID_FOLDER="$(dirname "$jarfile")"/"$PID_FOLDER"
! [[ "$LOG_FOLDER" == /* ]] && LOG_FOLDER="$(dirname "$jarfile")"/"$LOG_FOLDER"
! [[ -x "$PID_FOLDER" ]] && PID_FOLDER="/tmp"
! [[ -x "$LOG_FOLDER" ]] && LOG_FOLDER="/tmp"

# Set up defaults
[[ -z "$MODE" ]] && MODE="auto" # modes are "auto", "service" or "run"
[[ -z "$USE_START_STOP_DAEMON" ]] && USE_START_STOP_DAEMON="true"

# Create an identity for log/pid files
if [[ -z "$identity" ]]; then
  if [[ -n "$init_script" ]]; then
    identity="${init_script}"
  else
    identity=$(basename "${jarfile%.*}")_${jarfolder//\//}
  fi
fi

# Initialize log file name if not provided by the config file
[[ -z "$LOG_FILENAME" ]] && LOG_FILENAME="${identity}.log"

# Initialize stop wait time if not provided by the config file
[[ -z "$STOP_WAIT_TIME" ]] && STOP_WAIT_TIME="60"

# ANSI Colors
echoRed() { echo $'\e[0;31m'"$1"$'\e[0m'; }
echoGreen() { echo $'\e[0;32m'"$1"$'\e[0m'; }
echoYellow() { echo $'\e[0;33m'"$1"$'\e[0m'; }

# Utility functions
checkPermissions() {
  touch "$pid_file" &> /dev/null || { echoRed "Operation not permitted (cannot access pid file)"; return 4; }
  if $AUTOLOG;then
    touch "$log_file" &> /dev/null || { echoRed "Operation not permitted (cannot access log file)"; return 4; }
  fi
}


isRunning() {
  ps -p "$1" &> /dev/null
}

await_file() {
  end=$(date +%s)
  let "end+=10"
  while [[ ! -s "$1" ]]
  do
    now=$(date +%s)
    if [[ $now -ge $end ]]; then
      break
    fi
    sleep 1
  done
}

# Determine the script mode
action="run"
if [[ "$MODE" == "auto" && -n "$init_script" ]] || [[ "$MODE" == "service" ]]; then
  action="$1"
  shift
fi

# Build the pid and log filenames
PID_FOLDER="$PID_FOLDER/${identity}"
pid_file="$PID_FOLDER/${identity}.pid"
log_file="$LOG_FOLDER/$LOG_FILENAME"

# Determine the user to run as if we are root
# shellcheck disable=SC2012
[[ $(id -u) == "0" ]] && run_user=$(ls -ld "$jarfile" | awk '{print $3}')

# Find Java
if [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]]; then
    javaexe="$JAVA_HOME/bin/java"
elif type -p java > /dev/null 2>&1; then
    javaexe=$(type -p java)
elif [[ -x "/usr/bin/java" ]];  then
    javaexe="/usr/bin/java"
else
    echo "Unable to find Java"
    exit 1
fi

arguments=(-Dsun.misc.URLClassPath.disableJarChecking=true $JAVA_OPTS -jar "$jarfolder/$jarfile" $RUN_ARGS "$@")

# Action functions
start() {
  if [[ -f "$pid_file" ]]; then
    pid=$(cat "$pid_file")
    isRunning "$pid" && { echoYellow "Already running [$pid]"; return 0; }
  fi
  do_start "$@"
}

do_start() {
  working_dir=$(dirname "$jarfile")
  pushd "$working_dir" > /dev/null
  if [[ ! -e "$PID_FOLDER" ]]; then
    mkdir -p "$PID_FOLDER" &> /dev/null
    if [[ -n "$run_user" ]]; then
      chown "$run_user" "$PID_FOLDER"
    fi
  fi
  if [ $AUTOLOG = true ] && [[ ! -e "$log_file" ]]; then
    touch "$log_file" &> /dev/null
    if [[ -n "$run_user" ]]; then
      chown "$run_user" "$log_file"
    fi
  fi
  if [[ -n "$run_user" ]]; then
    checkPermissions || return $?
    if [ $USE_START_STOP_DAEMON = true ] && type start-stop-daemon > /dev/null 2>&1; then
      start-stop-daemon --start --quiet \
        --chuid "$run_user" \
        --name "$identity" \
        --make-pidfile --pidfile "$pid_file" \
        --background --no-close \
        --startas "$javaexe" \
        --chdir "$working_dir" \
        -- "${arguments[@]}" \
        > /dev/null 2>&1
      await_file "$pid_file"
    else
      if $AUTOLOG;then
        su -s /bin/sh -c "$javaexe $(printf "\"%s\" " "${arguments[@]}")  >> \"$log_file\" 2>&1 & echo \$!" "$run_user" > "$pid_file"
      else
        su -s /bin/sh -c "$javaexe $(printf "\"%s\" " "${arguments[@]}") > /dev/null 2>&1 & echo \$!" "$run_user" > "$pid_file"
      fi
    fi
    pid=$(cat "$pid_file")
  else
    checkPermissions || return $?
    if $AUTOLOG;then
      "$javaexe" "${arguments[@]}" >> "$log_file" 2>&1 &
    else
      "$javaexe" "${arguments[@]}" > /dev/null 2>&1 &
    fi
    pid=$!
    disown $pid
    echo "$pid" > "$pid_file"
  fi
  [[ -z $pid ]] && { echoRed "Failed to start"; return 1; }
  echoGreen "Started [$pid]"
}

stop() {
  working_dir=$(dirname "$jarfile")
  pushd "$working_dir" > /dev/null
  [[ -f $pid_file ]] || { echoYellow "Not running (pidfile not found)"; return 0; }
  pid=$(cat "$pid_file")
  isRunning "$pid" || { echoYellow "Not running (process ${pid}). Removing stale pid file."; rm -f "$pid_file"; return 0; }
  do_stop "$pid" "$pid_file"
}

do_stop() {
  curl -X POST -s -o /dev/null -d "ttl=60000&applicationName=$APPLICATION_NAME" $BOOTADMIN_URL
  kill "$1" &> /dev/null || { echoRed "Unable to kill process $1"; return 1; }
  for i in $(seq 1 $STOP_WAIT_TIME); do
    isRunning "$1" || { echoGreen "Stopped [$1]"; rm -f "$2"; return 0; }
    [[ $i -eq STOP_WAIT_TIME/2 ]] && kill "$1" &> /dev/null
    sleep 1
  done
  echoRed "Unable to kill process $1";
  return 1;
}

force_stop() {
  [[ -f $pid_file ]] || { echoYellow "Not running (pidfile not found)"; return 0; }
  pid=$(cat "$pid_file")
  isRunning "$pid" || { echoYellow "Not running (process ${pid}). Removing stale pid file."; rm -f "$pid_file"; return 0; }
  do_force_stop "$pid" "$pid_file"
}

do_force_stop() {
  kill -9 "$1" &> /dev/null || { echoRed "Unable to kill process $1"; return 1; }
  for i in $(seq 1 $STOP_WAIT_TIME); do
    isRunning "$1" || { echoGreen "Stopped [$1]"; rm -f "$2"; return 0; }
    [[ $i -eq STOP_WAIT_TIME/2 ]] && kill -9 "$1" &> /dev/null
    sleep 1
  done
  echoRed "Unable to kill process $1";
  return 1;
}

restart() {
  stop && start
}

force_reload() {
  working_dir=$(dirname "$jarfile")
  pushd "$working_dir" > /dev/null
  [[ -f $pid_file ]] || { echoRed "Not running (pidfile not found)"; return 7; }
  pid=$(cat "$pid_file")
  rm -f "$pid_file"
  isRunning "$pid" || { echoRed "Not running (process ${pid} not found)"; return 7; }
  do_stop "$pid" "$pid_file"
  do_start
}

status() {
  working_dir=$(dirname "$jarfile")
  pushd "$working_dir" > /dev/null
  [[ -f "$pid_file" ]] || { echoRed "Not running"; return 3; }
  pid=$(cat "$pid_file")
  isRunning "$pid" || { echoRed "Not running (process ${pid} not found)"; return 1; }
  echoGreen "Running [$pid]"
  return 0
}

run() {
  pushd "$(dirname "$jarfile")" > /dev/null
  "$javaexe" "${arguments[@]}"
  result=$?
  popd > /dev/null
  return "$result"
}

# Call the appropriate action function
case "$action" in
start)
  start "$@"; exit $?;;
stop)
  stop "$@"; exit $?;;
force-stop)
  force_stop "$@"; exit $?;;
restart)
  restart "$@"; exit $?;;
force-reload)
  force_reload "$@"; exit $?;;
status)
  status "$@"; exit $?;;
run)
  run "$@"; exit $?;;
*)
  echo "Usage: $0 {start|stop|force-stop|restart|force-reload|status|run}"; exit 1;
esac

exit 0
