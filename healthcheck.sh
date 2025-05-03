#!/bin/sh

# Check Flask/Gunicorn
curl -fsS http://localhost:5000/health >/dev/null || exit 1

# Check Docker daemon
docker info >/dev/null 2>&1 || exit 1

exit 0