#!/bin/sh
echo "Solarway Initializer: Checking Workflows for pre-deployment load..."
mkdir -p /data/workflows/
mkdir -p /data/credentials/

if [ "$(ls -A /data/workflows/ 2>/dev/null)" ]; then
    echo "Importing workflows..."
    n8n import:workflow --input=/data/workflows/ --separate || echo "Error loading workflows. Skipping..."
else
    echo "No workflows to import."
fi

if [ "$(ls -A /data/credentials/ 2>/dev/null)" ]; then
    echo "Importing credentials..."
    n8n import:credentials --input=/data/credentials/ --separate || echo "Error loading credentials. Skipping..."
else
    echo "No credentials to import."
fi

echo "Init Load Complete."
