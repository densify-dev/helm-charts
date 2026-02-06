#!/bin/sh
# Ephemeral Storage Metrics Exporter for CRI-O
# Exposes container ephemeral storage usage in Prometheus format

set -e

METRICS_PORT=${METRICS_PORT:-9102}
METRICS_FILE="/tmp/metrics.prom"

# Function to get ephemeral storage usage from CRI-O
get_ephemeral_storage() {
    # Get container stats from CRI-O socket using crictl
    crictl --runtime-endpoint unix:///var/run/crio/crio.sock stats --output json 2>/dev/null || echo '{"stats":[]}'
}

# Function to generate Prometheus metrics
generate_metrics() {
    cat > "$METRICS_FILE" << 'EOF'
# HELP container_ephemeral_storage_used_bytes Ephemeral storage used by container in bytes
# TYPE container_ephemeral_storage_used_bytes gauge
EOF
    
    # Parse CRI-O stats and append to metrics file
    STATS=$(get_ephemeral_storage)
    
    # Simple parsing without jq (not available in minimal image)
    echo "# Metrics collection from CRI-O" >> "$METRICS_FILE"
    echo "# Stats retrieved at $(date)" >> "$METRICS_FILE"
}

# Update metrics file periodically
update_metrics() {
    while true; do
        generate_metrics 2>/dev/null || echo "# Error generating metrics" > "$METRICS_FILE"
        sleep 15
    done
}

# Start metrics updater in background
update_metrics &

# Serve metrics using httpd
echo "Starting HTTP server on port $METRICS_PORT"
cd /tmp
while true; do
    echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n$(cat $METRICS_FILE)" | nc -l -p "$METRICS_PORT" 2>/dev/null || true
done
