#!/bin/bash

# Test script for Jellyfin container

# Get the IP address of the jellyfin-main container
JELLYFIN_IP=$(docker inspect jellyfin-main --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null)

if [ -z "$JELLYFIN_IP" ]; then
    echo "Error: jellyfin-main container not found or not running"
    exit 1
fi

echo "Found jellyfin-main at IP: $JELLYFIN_IP"
echo "Testing Jellyfin API..."
echo ""

# Test 1: Check if Jellyfin is running
echo "Step 1: Checking Jellyfin health..."
curl -s http://$JELLYFIN_IP:8096/health || echo "Health check failed"
echo ""
echo ""

# Test 2: Get system info
echo "Step 2: Getting Jellyfin system info..."
curl -s http://$JELLYFIN_IP:8096/System/Info/Public || echo "Could not retrieve system info"
echo ""
echo ""

# Test 3: List configured users (may be empty on fresh install)
echo "Step 3: Checking users endpoint..."
curl -s http://$JELLYFIN_IP:8096/Users || echo "Could not retrieve users"
echo ""
echo ""

echo "Test complete! Jellyfin web interface should be available at http://jellyfin-main:8096"
