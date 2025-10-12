FROM nginx:alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx config template
COPY nginx.conf /etc/nginx/templates/default.conf.template

# Copy frontend files to nginx html directory
COPY index.html /usr/share/nginx/html/
COPY static /usr/share/nginx/html/static/

# Create startup script to inject environment variable
COPY <<'EOF' /docker-entrypoint.sh
#!/bin/sh
set -e

# Set default for local dev if not provided
if [ -z "$BACKEND_INTERNAL_URL" ]; then
    export BACKEND_INTERNAL_URL="http://backend:9090"
    echo "Using default BACKEND_INTERNAL_URL: $BACKEND_INTERNAL_URL"
fi

# Substitute BACKEND_URL in nginx config
export BACKEND_URL=$BACKEND_INTERNAL_URL
envsubst '${BACKEND_URL}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf

echo "Nginx configured to proxy /api/* to: $BACKEND_URL"

# Start nginx
exec nginx -g 'daemon off;'
EOF

RUN chmod +x /docker-entrypoint.sh

# Expose port
EXPOSE 8082

# Run nginx with environment variable substitution
CMD ["/docker-entrypoint.sh"]