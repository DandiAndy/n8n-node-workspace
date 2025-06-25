#!/bin/sh

echo "Starting n8n with custom node and workflow watching..."

# Function to import workflows
import_workflows() {
    echo "Checking for workflows to import..."
    if [ -d "/home/node/.n8n/workflows-import" ]; then
        for workflow_file in /home/node/.n8n/workflows-import/*.json; do
            if [ -f "$workflow_file" ]; then
                echo "Importing workflow: $(basename "$workflow_file")"
                n8n import:workflow --input="$workflow_file" || echo "Warning: Failed to import $(basename "$workflow_file")"
            fi
        done
    fi
}

# Function to import credentials
import_credentials() {
    echo "Checking for credentials to import..."
    if [ -d "/home/node/.n8n/credentials-import" ]; then
        for credential_file in /home/node/.n8n/credentials-import/*.json; do
            if [ -f "$credential_file" ]; then
                echo "Importing credential: $(basename "$credential_file")"
                n8n import:credentials --input="$credential_file" || echo "Warning: Failed to import $(basename "$credential_file")"
            fi
        done
    fi
}

# Function to start n8n with initial imports
start_n8n() {
    # Import existing workflows and credentials on startup only
    import_workflows
    import_credentials
    echo "Starting n8n server..."
    n8n start &
    N8N_PID=$!
    echo "n8n started with PID: $N8N_PID"
}

# Create script for workflow watcher
create_workflow_watcher() {
    cat > /tmp/workflow_watcher.sh << 'EOF'
#!/bin/sh
echo "Workflow change detected, reimporting workflows..."
if [ -d "/home/node/.n8n/workflows-import" ]; then
    for workflow_file in /home/node/.n8n/workflows-import/*.json; do
        if [ -f "$workflow_file" ] && [ "$(basename "$workflow_file")" != "README.json" ]; then
            echo "Importing workflow: $(basename "$workflow_file")"
            n8n import:workflow --input="$workflow_file" || echo "Warning: Failed to import $(basename "$workflow_file")"
        fi
    done
fi
EOF
    chmod +x /tmp/workflow_watcher.sh
}

# Create script for credential watcher
create_credential_watcher() {
    cat > /tmp/credential_watcher.sh << 'EOF'
#!/bin/sh
echo "Credential change detected, reimporting credentials..."
if [ -d "/home/node/.n8n/credentials-import" ]; then
    for credential_file in /home/node/.n8n/credentials-import/*.json; do
        if [ -f "$credential_file" ] && [ "$(basename "$credential_file")" != "README.json" ]; then
            echo "Importing credential: $(basename "$credential_file")"
            n8n import:credentials --input="$credential_file" || echo "Warning: Failed to import $(basename "$credential_file")"
        fi
    done
fi
EOF
    chmod +x /tmp/credential_watcher.sh
}

# Create script for node watcher that restarts n8n
create_node_watcher() {
    cat > /tmp/node_watcher.sh << 'EOF'
#!/bin/sh
echo "Custom node change detected, restarting n8n..."
# Kill existing n8n process by finding it
N8N_PID=$(pgrep -f "n8n start")
if [ ! -z "$N8N_PID" ]; then
    echo "Stopping n8n (PID: $N8N_PID)..."
    kill $N8N_PID
    sleep 3
    # If still running, force kill
    if kill -0 $N8N_PID 2>/dev/null; then
        echo "Force killing n8n..."
        kill -9 $N8N_PID
        sleep 1
    fi
fi

# Import workflows and credentials
if [ -d "/home/node/.n8n/workflows-import" ]; then
    for workflow_file in /home/node/.n8n/workflows-import/*.json; do
        if [ -f "$workflow_file" ] && [ "$(basename "$workflow_file")" != "README.json" ]; then
            echo "Importing workflow: $(basename "$workflow_file")"
            n8n import:workflow --input="$workflow_file" || echo "Warning: Failed to import $(basename "$workflow_file")"
        fi
    done
fi

if [ -d "/home/node/.n8n/credentials-import" ]; then
    for credential_file in /home/node/.n8n/credentials-import/*.json; do
        if [ -f "$credential_file" ] && [ "$(basename "$credential_file")" != "README.json" ]; then
            echo "Importing credential: $(basename "$credential_file")"
            n8n import:credentials --input="$credential_file" || echo "Warning: Failed to import $(basename "$credential_file")"
        fi
    done
fi

echo "Starting n8n..."
exec n8n start
EOF
    chmod +x /tmp/node_watcher.sh
}

# Function to cleanup background processes
cleanup() {
    echo "Cleaning up..."
    # Kill n8n process by finding it
    N8N_PID=$(pgrep -f "n8n start")
    if [ ! -z "$N8N_PID" ]; then
        echo "Stopping n8n (PID: $N8N_PID)..."
        kill $N8N_PID
        sleep 2
        # If still running, force kill
        if kill -0 $N8N_PID 2>/dev/null; then
            echo "Force killing n8n..."
            kill -9 $N8N_PID
        fi
    fi
    # Kill any remaining nodemon processes
    pkill -f nodemon
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Start n8n with initial imports
start_n8n

# Start watchers based on what directories exist
watchers_started=0

# Watch for custom node changes (requires restart)
if [ -d "/home/node/.n8n/custom" ] && [ "$(ls -A /home/node/.n8n/custom)" ]; then
    echo "Starting custom node watcher..."
    create_node_watcher
    nodemon \
        --watch "/home/node/.n8n/custom" \
        --ext js,json,ts \
        --ignore node_modules/ \
        --ignore "*.log" \
        --ignore "**/README.md" \
        --delay 2 \
        --exec "/tmp/node_watcher.sh" &
    NODE_WATCHER_PID=$!
    echo "Custom node watcher started with PID: $NODE_WATCHER_PID"
    watchers_started=$((watchers_started + 1))
fi

# Watch for workflow changes (import only)
if [ -d "/home/node/.n8n/workflows-import" ]; then
    echo "Starting workflow watcher..."
    create_workflow_watcher
    nodemon \
        --watch "/home/node/.n8n/workflows-import" \
        --ext json \
        --ignore "**/README.json" \
        --delay 1 \
        --exec "/tmp/workflow_watcher.sh" &
    WORKFLOW_WATCHER_PID=$!
    echo "Workflow watcher started with PID: $WORKFLOW_WATCHER_PID"
    watchers_started=$((watchers_started + 1))
fi

# Watch for credential changes (import only)
if [ -d "/home/node/.n8n/credentials-import" ]; then
    echo "Starting credential watcher..."
    create_credential_watcher
    nodemon \
        --watch "/home/node/.n8n/credentials-import" \
        --ext json \
        --ignore "**/README.json" \
        --delay 1 \
        --exec "/tmp/credential_watcher.sh" &
    CREDENTIAL_WATCHER_PID=$!
    echo "Credential watcher started with PID: $CREDENTIAL_WATCHER_PID"
    watchers_started=$((watchers_started + 1))
fi

if [ $watchers_started -eq 0 ]; then
    echo "No directories to watch found, n8n running normally..."
else
    echo "Started $watchers_started watcher(s). Press Ctrl+C to stop all processes."
fi

# Wait for all background processes
wait
