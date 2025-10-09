"""
Storage handler for managing document storage - supports local filesystem, GCS, and S3
"""
import os
from io import BytesIO
from docx import Document as DocxDocument
import logging

logger = logging.getLogger(__name__)

# Check storage mode
USE_GCS = os.getenv('USE_GCS', 'false').lower() == 'true'
USE_S3 = os.getenv('USE_S3', 'false').lower() == 'true'

# Initialize storage clients
if USE_GCS:
    from google.cloud import storage
    GCS_BUCKET_NAME = os.getenv('GCS_BUCKET_NAME')
    gcs_storage_client = storage.Client()
    gcs_bucket = gcs_storage_client.bucket(GCS_BUCKET_NAME)
    logger.info(f"Initialized GCS storage with bucket: {GCS_BUCKET_NAME}")
elif USE_S3:
    import boto3
    S3_BUCKET_NAME = os.getenv('S3_BUCKET_NAME')
    AWS_REGION = os.getenv('AWS_REGION', 'us-east-1')
    s3_client = boto3.client('s3', region_name=AWS_REGION)
    logger.info(f"Initialized S3 storage with bucket: {S3_BUCKET_NAME} in region: {AWS_REGION}")
else:
    logger.info("Using local filesystem storage")


class StorageHandler:
    """Handles document storage operations for local, GCS, and S3"""

    @staticmethod
    def save_document(document: DocxDocument, filename: str) -> str:
        """
        Save a Word document to storage

        Args:
            document: python-docx Document object
            filename: Name of the file to save

        Returns:
            str: Path or URL to the saved document
        """
        if USE_GCS:
            return StorageHandler._save_to_gcs(document, filename)
        elif USE_S3:
            return StorageHandler._save_to_s3(document, filename)
        else:
            return StorageHandler._save_to_local(document, filename)

    @staticmethod
    def _save_to_gcs(document: DocxDocument, filename: str) -> str:
        """Save document to Google Cloud Storage"""
        try:
            # Create in-memory file
            file_stream = BytesIO()
            document.save(file_stream)
            file_stream.seek(0)

            # Upload to GCS
            blob = gcs_bucket.blob(f"documents/{filename}")
            blob.upload_from_file(file_stream, content_type='application/vnd.openxmlformats-officedocument.wordprocessingml.document')

            logger.info(f"Document saved to GCS: gs://{GCS_BUCKET_NAME}/documents/{filename}")
            return f"gs://{GCS_BUCKET_NAME}/documents/{filename}"
        except Exception as e:
            logger.error(f"Error saving document to GCS: {e}")
            raise

    @staticmethod
    def _save_to_s3(document: DocxDocument, filename: str) -> str:
        """Save document to AWS S3"""
        try:
            # Create in-memory file
            file_stream = BytesIO()
            document.save(file_stream)
            file_stream.seek(0)

            # Upload to S3
            key = f"documents/{filename}"
            s3_client.put_object(
                Bucket=S3_BUCKET_NAME,
                Key=key,
                Body=file_stream,
                ContentType='application/vnd.openxmlformats-officedocument.wordprocessingml.document'
            )

            logger.info(f"Document saved to S3: s3://{S3_BUCKET_NAME}/{key}")
            return f"s3://{S3_BUCKET_NAME}/{key}"
        except Exception as e:
            logger.error(f"Error saving document to S3: {e}")
            raise

    @staticmethod
    def _save_to_local(document: DocxDocument, filename: str) -> str:
        """Save document to local filesystem"""
        try:
            # Use mounted volume path in Docker, fallback to local path for development
            admin_generated_docs_path = os.getenv('ADMIN_DOCS_PATH',
                "/Users/jhuajun/projects/learnings/compliance_procedure_admin/backend/generated_docs")

            # Ensure directory exists
            os.makedirs(admin_generated_docs_path, exist_ok=True)

            file_path = os.path.join(admin_generated_docs_path, filename)
            document.save(file_path)

            logger.info(f"Document saved to local storage: {file_path}")
            return file_path
        except Exception as e:
            logger.error(f"Error saving document to local storage: {e}")
            raise

    @staticmethod
    def get_document(filename: str) -> BytesIO:
        """
        Retrieve a document from storage

        Args:
            filename: Name of the file to retrieve

        Returns:
            BytesIO: In-memory file object
        """
        if USE_GCS:
            return StorageHandler._get_from_gcs(filename)
        elif USE_S3:
            return StorageHandler._get_from_s3(filename)
        else:
            return StorageHandler._get_from_local(filename)

    @staticmethod
    def _get_from_gcs(filename: str) -> BytesIO:
        """Retrieve document from Google Cloud Storage"""
        try:
            blob = gcs_bucket.blob(f"documents/{filename}")
            file_stream = BytesIO()
            blob.download_to_file(file_stream)
            file_stream.seek(0)

            logger.info(f"Document retrieved from GCS: {filename}")
            return file_stream
        except Exception as e:
            logger.error(f"Error retrieving document from GCS: {e}")
            raise

    @staticmethod
    def _get_from_s3(filename: str) -> BytesIO:
        """Retrieve document from AWS S3"""
        try:
            key = f"documents/{filename}"
            response = s3_client.get_object(Bucket=S3_BUCKET_NAME, Key=key)
            file_stream = BytesIO(response['Body'].read())
            file_stream.seek(0)

            logger.info(f"Document retrieved from S3: {filename}")
            return file_stream
        except Exception as e:
            logger.error(f"Error retrieving document from S3: {e}")
            raise

    @staticmethod
    def _get_from_local(filename: str) -> BytesIO:
        """Retrieve document from local filesystem"""
        try:
            admin_generated_docs_path = os.getenv('ADMIN_DOCS_PATH',
                "/Users/jhuajun/projects/learnings/compliance_procedure_admin/backend/generated_docs")

            file_path = os.path.join(admin_generated_docs_path, filename)

            if not os.path.exists(file_path):
                raise FileNotFoundError(f"File not found: {file_path}")

            with open(file_path, 'rb') as f:
                file_stream = BytesIO(f.read())

            logger.info(f"Document retrieved from local storage: {filename}")
            return file_stream
        except Exception as e:
            logger.error(f"Error retrieving document from local storage: {e}")
            raise

    @staticmethod
    def document_exists(filename: str) -> bool:
        """
        Check if a document exists in storage

        Args:
            filename: Name of the file to check

        Returns:
            bool: True if document exists, False otherwise
        """
        if USE_GCS:
            return StorageHandler._exists_in_gcs(filename)
        elif USE_S3:
            return StorageHandler._exists_in_s3(filename)
        else:
            return StorageHandler._exists_in_local(filename)

    @staticmethod
    def _exists_in_gcs(filename: str) -> bool:
        """Check if document exists in GCS"""
        try:
            blob = gcs_bucket.blob(f"documents/{filename}")
            return blob.exists()
        except Exception as e:
            logger.error(f"Error checking document existence in GCS: {e}")
            return False

    @staticmethod
    def _exists_in_s3(filename: str) -> bool:
        """Check if document exists in S3"""
        try:
            key = f"documents/{filename}"
            s3_client.head_object(Bucket=S3_BUCKET_NAME, Key=key)
            return True
        except s3_client.exceptions.NoSuchKey:
            return False
        except Exception as e:
            logger.error(f"Error checking document existence in S3: {e}")
            return False

    @staticmethod
    def _exists_in_local(filename: str) -> bool:
        """Check if document exists in local storage"""
        try:
            admin_generated_docs_path = os.getenv('ADMIN_DOCS_PATH',
                "/Users/jhuajun/projects/learnings/compliance_procedure_admin/backend/generated_docs")
            file_path = os.path.join(admin_generated_docs_path, filename)
            return os.path.exists(file_path)
        except Exception as e:
            logger.error(f"Error checking document existence in local storage: {e}")
            return False
