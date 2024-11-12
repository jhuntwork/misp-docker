#!/bin/bash

term_proc() {
    echo "Entrypoint NGINX caught SIGTERM signal!"
    echo "Killing process $master_pid"
    kill -TERM "$master_pid" 2>/dev/null
}

# Initialize NGINX
/configure_nginx.sh
if [ -n "$KUBERNETES_SERVICE_HOST" ]; then
    exec nginx -g 'daemon off;'
else
    trap term_proc SIGTERM
    nginx -g 'daemon off;' & master_pid=$!
    # Wait for it
    wait "$master_pid"
fi
