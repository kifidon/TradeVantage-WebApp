

# TradeVantage WebApp – Full Stack Cloud Microservices

TradeVantage is a cloud-native trading automation platform composed of two containerized microservices: a **Django-based backend API** and a **Next.js-based frontend client**. Both services are independently containerized, deployed to a Kubernetes cluster, and maintained using a GitHub Actions CI/CD pipeline.

---

## 🧱 Architecture Overview

```
Client (Browser)
   ↓
Frontend (Next.js, Tailwind)
   ↓
Backend (Django REST, PostgreSQL)
   ↓                      ↓
Supabase (Storage, RLS)   Stripe Webhooks → Backend (Webhook Endpoint)
   ↓
Kubernetes (Deployments, HPA, Services)
```

---

## 📦 Microservices

### 1. **Backend API (Django)**
- REST API with JWT authentication
- Expert Advisor model & user subscription validation
- Trade data ingestion and management
- Redis + Celery for background tasks
- Dockerized and deployed with Kubernetes
- Horizontal scaling with HPA

**Deployment File**: `deployments/backend-deployment.yaml`  
**Autoscaling File**: `deployments/backend-HPA.yaml`

### 2. **Frontend Client (Next.js)**
- User dashboard for managing Expert Advisors
- Authentication and secure API interaction
- Supabase image rendering and EA previews
- Real-time purchase confirmations
- Deployed via Vercel for staging, Dockerized for production

**Deployment File**: `deployments/frontend-deployment.yaml`

---

## ⚙️ CI/CD Pipeline

CI/CD is handled via GitHub Actions:

- On push to `main`, backend and frontend Docker images are built
- Images are pushed to Docker Hub
- Kubernetes manifests (`.yaml`) are applied using `kubectl`
- Secrets and env variables are injected securely using Kubernetes Secrets

---

## 🚀 Deployment Instructions

```bash
# Apply backend deployment and autoscaling config
kubectl apply -f deployments/backend-deployment.yaml
kubectl apply -f deployments/backend-HPA.yaml

# Apply frontend deployment
kubectl apply -f deployments/frontend-deployment.yaml
```

Make sure your kubeconfig is set and the Docker images are pushed to the correct container registry before deploying.

---

## 🐳 Local Development with Docker Compose

This repository includes the following files for local development and testing:

### 🔹 `docker_compose.yml`
Defines a multi-container setup for running the frontend and backend locally:
- **backend**: Uses `DockerFile.django` to build the Django app
- **frontend**: Assumes a Dockerfile exists under `/frontend`
- Includes network aliasing and environment variables for service interconnection

To run locally:
```bash
docker compose up --build
```

### 🔹 `DockerFile.django`
Builds the Django backend as a production-ready container:
- Installs Python packages from `requirements.txt`
- Sets up the app inside `/app`
- Runs with `gunicorn` for WSGI production serving
- Exposes port 8000

### 🔹 `frontend/DockerFile`
Builds the NEXT.js frontend as a production-ready container:


Make sure `.env` files are configured and mount volumes if needed for local testing.

---

## 📁 Repository Structure

```text
TradeVantage-WebApp/
├── backend/                   # Django backend
├── frontend/                  # Next.js frontend
├── deployments/               # Kubernetes deployment YAML files
│   ├── backend-deployment.yaml
│   ├── backend-HPA.yaml
│   └── frontend-deployment.yaml
├── docker_compose.yml         # Local development
├── DockerFile.django
└── Readme.md                  # Project overview
```

---

For service-specific details, refer to the individual README files inside `frontend/` and `backend/`.
