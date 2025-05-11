# TradeVantage Backend API

This Django project (`tv_backend`) provides the backend for the TradeVantage Web App, including user authentication, trade management, and subscription validation. It consists of multiple apps, each exposing RESTful endpoints secured with JWT.

## Table of Contents

1. [Project Structure](#project-structure)  
2. [Authentication & Accounts](#authentication--accounts)  
3. [Dashboard API](#dashboard-api)  
4. [Market API](#market-api)  
5. [Authentication Requirements](#authentication-requirements)  

---

## Project Structure

```text
Backend-Django/      # Root directory with requirnemnts.txt, manage.py, etc.
├── tv-backend/      # Django project directory with settings and app.
├── accounts/        # Custom User model and JWT endpoints
├── dashboard_api/   # Trade management, filtering, subscriptions
├── market_api/      # (Market data & ExpertAdvisor models)
└── manage.py
```

---

## Authentication & Accounts

Handles user registration and login using a custom User model and JWT.

- **Custom User Model**  
  - UUID primary key, email as login, full name, role, timestamps  
- **Endpoints**  
  - `POST /api/register/` — Create a new user  
  - `POST /api/login/` — Obtain access & refresh tokens  
  - `POST /api/login/refresh/` — Refresh an access token  

**Sample Registration Request**  
```json
POST /api/register/
{
  "email": "user@example.com",
  "full_name": "User Name",
  "password": "SecurePass123",
  "role": "programmer"
}
```

**Sample Login Response**  
```json
POST /api/login/
{
  "access": "<jwt_access_token>",
  "refresh": "<jwt_refresh_token>"
}
```

---

## Dashboard API

Manages user trades and validates subscriptions to Expert Advisors.

- **Key Models**  
  - **Trade**: id, user, expert, open_time, close_time, profit, lot_size  
  - **ExpertUser**: links user subscriptions to ExpertAdvisor  

- **Features**  
  - Create, retrieve, update, and list trades (deletion disabled)  
  - Filter by expert, time ranges, profit, and lot size  
  - Check subscription status for an Expert Advisor  

- **Endpoints**  
  - `GET /api/trade/` — List trades  
  - `POST /api/trade/` — Create a trade  
  - `GET /api/trade/{id}/` — Retrieve a trade  
  - `PUT /api/trade/{id}/` — Full update  
  - `PATCH /api/trade/{id}/` — Partial update  
  - `DELETE /api/trade/{id}/` — Disabled (405)  
  - `GET /api/trade-auth/{magic_number}/` — Check subscription  

**Sample Trade Object**  
```json
{
  "id": "uuid",
  "user": "user@example.com",
  "expert": "EA1234MAGIC",
  "open_time": "2025-05-03T14:00:00Z",
  "close_time": null,
  "profit": "150.00",
  "lot_size": "2.00"
}
```

---

## Market API

_Provides data models and endpoints for ExpertAdvisor definitions and market-related operations._

- **Key Models**  
  - **ExpertAdvisor**: name, description, version, author, magic_number  
  - **(Additional market endpoints go here.)**  

- **Endpoints**  
  - `GET /api/experts/` — List available Expert Advisors  
  - `GET /api/experts/{magic_number}/` — Retrieve expert details  

---

## Authentication Requirements

- All endpoints under `/api/` (except registration and login) require a valid JWT in the `Authorization: Bearer <token>` header.
- Tokens expire; use `/api/login/refresh/` to obtain fresh access tokens.

---

_For full request/response examples and detailed parameter lists, refer to each app’s README in the repository: `accounts/Readme.md`, `dashboard_api/Readme.md`, and `market_api/Readme.md`._  