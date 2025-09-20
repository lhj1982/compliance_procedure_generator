FROM python:3.11-slim

WORKDIR /app

# Copy frontend files
COPY . .

# Expose port
EXPOSE 8082

# Run simple HTTP server
CMD ["python3", "-m", "http.server", "8082"]