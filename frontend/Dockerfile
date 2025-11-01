FROM nginx:alpine

# Copy static files
COPY . /usr/share/nginx/html/

# Copy nginx configuration template
COPY nginx.conf /etc/nginx/templates/default.conf.template

# Remove default nginx configuration
RUN rm /etc/nginx/conf.d/default.conf

# Start Nginx with environment variable substitution
CMD ["nginx", "-g", "daemon off;"]