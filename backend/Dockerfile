FROM python:3.11-slim

WORKDIR /app

# Install system dependencies with retry logic
RUN apt-get update --fix-missing && \
    apt-get install -y --no-install-recommends \
    gcc \
    postgresql-client \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org && \
    pip install --no-cache-dir --retries 3 --timeout 60 --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org -r requirements.txt

# Copy application code
COPY . .

# Create generated_docs directory
RUN mkdir -p generated_docs

# Expose port
EXPOSE 9090

# Run the application
CMD ["python", "server.py"]