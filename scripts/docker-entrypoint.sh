#!/usr/bin/env bash
set -Eeo pipefail

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
# "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
  local var="$1"
  local fileVar="${var}_FILE"
  local def="${2:-}"
  # Do not continue if _FILE env is not set
  if ! [ "${!fileVar:-}" ]; then
    return
  elif [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
    echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
    exit 1
  fi
  local val="$def"
  if [ "${!var:-}" ]; then
    val="${!var}"
  elif [ "${!fileVar:-}" ]; then
    val="$(< "${!fileVar}")"
  fi
  export "$var"="$val"
  unset "$fileVar"
}

export KONG_NGINX_DAEMON=${KONG_NGINX_DAEMON:=off}

if [[ "$1" == "kong" ]]; then

  all_kong_options="/usr/local/share/lua/5.1/kong/templates/kong_defaults.lua"
  set +Eeo pipefail
  while IFS='' read -r LINE || [ -n "${LINE}" ]; do
      opt=$(echo "$LINE" | grep "=" | sed "s/=.*$//" | sed "s/ //" | tr '[:lower:]' '[:upper:]')
      file_env "KONG_$opt"
  done < $all_kong_options
  set -Eeo pipefail

  file_env KONG_PASSWORD
  PREFIX=${KONG_PREFIX:=/usr/local/kong}

  if [[ "$2" == "docker-start" ]]; then
    if [ -n "$WALLARM_MODE" ]; then
      sed -i -e "s|wallarm_mode monitoring|wallarm_mode $WALLARM_MODE|g" /usr/local/share/lua/5.1/kong/templates/nginx_kong.lua
    fi
    if [ -n "$WALLARM_APPLICATION" ]; then
      sed -i -e "s|wallarm_application 1|wallarm_application $WALLARM_APPLICATION|g" /usr/local/share/lua/5.1/kong/templates/nginx_kong.lua
    fi
    kong prepare -p "$PREFIX" "$@"

    ln -sf /dev/stdout $PREFIX/logs/access.log
    ln -sf /dev/stdout $PREFIX/logs/admin_access.log
    ln -sf /dev/stderr $PREFIX/logs/error.log

    if [ -n "$WALLARM_API_HOST" ]; then
      args="$args -H $WALLARM_API_HOST"
    fi
    if [ -n "$WALLARM_LABELS" ]; then
      args="$args --labels $WALLARM_LABELS"
    fi
    if [ -n "$TARANTOOL_MEMORY_GB" ]; then
      sed -i -e "s|SLAB_ALLOC_ARENA=1.0|SLAB_ALLOC_ARENA=$TARANTOOL_MEMORY_GB|g" /opt/wallarm/env.list
    fi
    /opt/wallarm/register-node $args
    /opt/wallarm/supervisord.sh &

    exec /usr/local/openresty/nginx/sbin/nginx \
      -p "$PREFIX" \
      -c nginx.conf
  fi
fi

exec "$@"
