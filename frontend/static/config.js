// Backend API Configuration for GCP Cloud Run
// This file should be generated/updated during deployment with the actual backend URL

// For GCP Cloud Run deployment:
// Replace BACKEND_URL_PLACEHOLDER with the actual backend Cloud Run URL during terraform apply
// Example: https://cp-backend-dev-123456.europe-north1.run.app

// IMPORTANT: Set this to your backend Cloud Run service URL
// Get this from terraform output: terraform output backend_url
window.APP_CONFIG = {
    BACKEND_URL: "BACKEND_URL_PLACEHOLDER"
};
