# Custom MLflow image with PostgreSQL and S3 support
# Base: Official MLflow image
FROM ghcr.io/mlflow/mlflow:v2.9.2

# Metadata
LABEL maintainer="AI Hyperscaler Project"
LABEL description="MLflow Tracking Server with PostgreSQL and MinIO S3 support"
LABEL version="2.9.2"

# Install PostgreSQL client library and AWS SDK
# Pin versions for reproducibility
RUN pip install --no-cache-dir \
    psycopg2-binary==2.9.9 \
    boto3==1.34.44

# Verify installations
RUN python -c "import psycopg2; import boto3; print('Dependencies installed successfully')"

# Default command (can be overridden in deployment)
CMD ["mlflow", "server", "--help"]
