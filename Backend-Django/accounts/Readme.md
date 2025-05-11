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


## Accounts API Documentation

### User Registration

- **Request**  
  ```http
  POST /api/register/
  Content-Type: application/json

  {
    "email": "testuser@example.com",
    "full_name": "Test User",
    "password": "securepassword123",
    "role": "programmer"
  }
  ```

- **Responses**  
  - **201 Created**  
    ```json
    {
      "email": "testuser@example.com",
      "full_name": "Test User",
      "role": "programmer"
    }
    ```
  - **400 Bad Request**  
    ```json
    {
      "email": ["This field is required."],
      "password": ["Ensure this field has at least 8 characters."],
      "role": ["\"invalid_role\" is not a valid choice."]
    }
    ```

### User Login

- **Request**  
  ```http
  POST /api/login/
  Content-Type: application/json

  {
    "email": "existing@example.com",
    "password": "securepass"
  }
  ```

- **Responses**  
  - **200 OK**  
    ```json
    {
      "access": "<jwt_access_token>",
      "refresh": "<jwt_refresh_token>"
    }
    ```
  - **401 Unauthorized**  
    ```json
    {
      "detail": "No active account found with the given credentials"
    }
    ```

