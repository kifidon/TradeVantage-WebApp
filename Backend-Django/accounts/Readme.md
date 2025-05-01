# Accounts API

**Accounts API** is a Django app within the TradeVantage project responsible for user authentication and management, using a custom User model and JWT-based endpoints.

## Features

- **Custom User Model**  
  - UUID primary key, email as login, full name, role, timestamps  
- **Registration & Login**  
  - `POST /api/register/` for new user signup  
  - `POST /api/login/` to obtain JWT access & refresh tokens  
  - `POST /api/login/refresh/` to refresh access tokens  
- **Permissions**  
  - JWT-based authentication for protected endpoints  

## Models

### User
- **id** (UUIDField, PK)  
- **email** (EmailField, unique)  
- **full_name** (CharField)  
- **role** (CharField, choices: user, programmer)  
- **is_active**, **is_staff**, **is_superuser** (booleans)  
- **date_joined** (DateTimeField)  

## API Endpoints

| Method | Endpoint                | Description                         |
|--------|-------------------------|-------------------------------------|
| POST   | `/api/register/`        | Create a new user account           |
| POST   | `/api/login/`           | Obtain JWT access & refresh tokens  |
| POST   | `/api/login/refresh/`   | Refresh an access token             |

## Example JSON

### Registration Request
```json
{
  "email": "jane.doe@example.com",
  "full_name": "Jane Doe",
  "password": "securePass123",
  "role": "programmer"
}
```

### Registration Response
```json
{
  "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "email": "jane.doe@example.com",
  "full_name": "Jane Doe",
  "role": "programmer",
  "date_joined": "2025-05-01T10:00:00Z"
}
```

### Token Request
```json
{
  "email": "jane.doe@example.com",
  "password": "securePass123"
}
```

### Token Response
```json
{
  "access": "eyJ0eXAiOiJKV1QiLCJhbGci...",
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGci..."
}
```

## URL Patterns (JSON Format)
```json
{
  "RegisterView": {
    "create": "/api/register/"
  },
  "TokenObtainPairView": {
    "create": "/api/login/"
  },
  "TokenRefreshView": {
    "create": "/api/login/refresh/"
  }
}
```

## Admin

- Registered model: `User`  
- Configured with list display, filters, and search on email & role  

## Testing

- Run tests for Accounts API:
  ```bash
  python manage.py test accounts --keepdb
  ```

## Contributing

1. Fork the repo  
2. Open a branch `feature/accounts-readme`  
3. Submit a pull request  
