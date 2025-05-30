# TradeVantage Backend API – Django Microservice

This is the backend service for **TradeVantage**, a cloud-native trading automation platform. Built with **Django** and the **Django REST Framework**, it provides user authentication, trade management, and subscription validation via secure, stateless APIs. This service is containerized using Docker and deployed to a Kubernetes cluster with GitHub Actions-based CI/CD.

---

## 🔧 Tech Stack

- Django + Django REST Framework
- PostgreSQL (via Supabase)
- JWT Authentication (SimpleJWT)
- Docker + Kubernetes + HPA
- GitHub Actions for CI/CD

---

## 📁 Project Structure

```text
tv_backend/         # Django project root
├── accounts/        # Custom user model and JWT logic
├── dashboard_api/   # Trade handling & subscription checks
├── market_api/      # ExpertAdvisor & market endpoint
├── manage.py
├── requirements.txt
```

---

## 🔐 Authentication & User Management

- **Custom User Model**
  - UUID primary key, email login, full name, user roles
- **JWT Endpoints**
  - `POST /api/register/` – Register a new user
  - `POST /api/login/` – Obtain access & refresh tokens
  - `POST /api/login/refresh/` – Refresh access token

**Sample Login Response**
```json
{
  "access": "<jwt_access_token>",
  "refresh": "<jwt_refresh_token>"
}
```

---

## 📊 Dashboard API (Trade Management)

Handles all trade activity and subscription verification.

- **Key Models**
  - `User`: Tracks user roles and permissions
  - `ExpertAdvisor`: Defines EAs with parameters
  - `ExpertUser`: Maps EAs to users
  - `Trade`: Tracks user trades with metadata
  - `ExpertUser`: Maps user subscriptions to EAs


---

## 📈 Market API (Expert Advisors)

Provides EA definitions and metadata.

- **Key Models**
  - `ExpertAdvisor`: Includes magic_number, version, author, etc.

- **Endpoints**
  - `GET /api/experts/` – List all EAs
  - `GET /api/experts/{magic_number}/` – Get EA details

---

## 🔐 Auth Requirements

All `/api/` endpoints require a valid JWT in the `Authorization: Bearer <token>` header (except login/register functions). Use `/api/login/refresh/` to refresh tokens.

---

## 🚀 Deployment Notes

- This service is deployed via Kubernetes using Docker containers.
- CI/CD via GitHub Actions builds, pushes, and applies manifests automatically.
- Sensitive environment variables are injected via Kubernetes secrets.

---

For full schema, serializers, and test coverage, see the individual app-level READMEs under `accounts/`, `dashboard_api/`, and `market_api/`.