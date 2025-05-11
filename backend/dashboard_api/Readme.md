

# dashboard_api

This Django app provides authenticated REST endpoints for managing and querying user trades, with built-in filtering and subscription validation for Expert Advisors.

## Features

- **Trade Management**  
  - Create new trades associated with the authenticated user  
  - Retrieve, update (partial/full), and list trades  
  - Deletion disabled via API (returns 405 Method Not Allowed)  
- **Filtering & Pagination**  
  - Filter trades by expert, open/close time ranges, profit, and lot size  
  - Built-in pagination support  
- **Subscription Check**  
  - Validate if the authenticated user has an active subscription for a given Expert Advisor  
  - Returns `200 OK` if active, or `410 Gone` if expired  

## Models

### Trade
- **id** (UUID) – Primary key  
- **user** (ForeignKey to `accounts.User`) – Owner of the trade  
- **expert** (ForeignKey to `market_api.ExpertAdvisor`) – Associated Expert Advisor  
- **open_time** (DateTime) – When the trade was opened  
- **close_time** (DateTime, optional) – When the trade was closed  
- **profit** (Decimal) – Profit or loss amount  
- **lot_size** (Decimal) – Trade size  


## API Endpoints

All endpoints are prefixed with `/api/` and require a Bearer token Authorization header.

### 1. List & Create Trades

```
GET  /api/trade/            # List trades for authenticated user
POST /api/trade/            # Create a new trade
```

#### List Trades

- **Request**  
  ```http
  GET /api/trade/?expert=EA1234MAGIC&profit_min=0&profit_max=100
  Authorization: Bearer <token>
  ```

- **Response (200 OK)**  
  ```json
  [
    {
      "id": "a1b2c3d4-5678-90ab-cdef-1234567890ab",
      "user": "user1@example.com",
      "expert": "EA1234MAGIC",
      "open_time": "2025-05-03T14:00:00Z",
      "close_time": null,
      "profit": "150.00",
      "lot_size": "2.00"
    },
    {
      "id": "b2c3d4e5-6789-01ab-cdef-234567890abc",
      "user": "user1@example.com",
      "expert": "EA1234MAGIC",
      "open_time": "2025-05-03T13:00:00Z",
      "close_time": "2025-05-03T15:30:00Z",
      "profit": "-50.00",
      "lot_size": "1.00"
    }
  ]
  ```

#### Create Trade

- **Request**  
  ```http
  POST /api/trade/
  Content-Type: application/json
  Authorization: Bearer <token>

  {
    "expert": "EA1234MAGIC",
    "open_time": "2025-05-03T14:00:00Z",
    "profit": "150.00",
    "lot_size": "2.00"
  }
  ```

- **Response (201 Created)**  
  ```json
  {
    "id": "a1b2c3d4-5678-90ab-cdef-1234567890ab",
    "user": "user1@example.com",
    "expert": "EA1234MAGIC",
    "open_time": "2025-05-03T14:00:00Z",
    "close_time": null,
    "profit": "150.00",
    "lot_size": "2.00"
  }
  ```

### 2. Retrieve, Update & Partial Update a Trade

```
GET   /api/trade/{id}/       # Retrieve trade details
PUT   /api/trade/{id}/       # Full update (all writable fields)
PATCH /api/trade/{id}/       # Partial update (e.g., profit only)
DELETE /api/trade/{id}/      # Not allowed (405 Method Not Allowed)
```

#### Retrieve a Trade

- **Request**  
  ```http
  GET /api/trade/a1b2c3d4-5678-90ab-cdef-1234567890ab/
  Authorization: Bearer <token>
  ```

- **Response (200 OK)**  
  ```json
  {
    "id": "a1b2c3d4-5678-90ab-cdef-1234567890ab",
    "user": "user1@example.com",
    "expert": "EA1234MAGIC",
    "open_time": "2025-05-03T14:00:00Z",
    "close_time": null,
    "profit": "150.00",
    "lot_size": "2.00"
  }
  ```

#### Full Update

- **Request**  
  ```http
  PUT /api/trade/a1b2c3d4-5678-90ab-cdef-1234567890ab/
  Content-Type: application/json
  Authorization: Bearer <token>

  {
    "expert": "EA1234MAGIC",
    "open_time": "2025-05-03T14:00:00Z",
    "close_time": "2025-05-03T16:00:00Z",
    "profit": "175.00",
    "lot_size": "2.00"
  }
  ```

- **Response (200 OK)**  
  ```json
  {
    "id": "a1b2c3d4-5678-90ab-cdef-1234567890ab",
    "user": "user1@example.com",
    "expert": "EA1234MAGIC",
    "open_time": "2025-05-03T14:00:00Z",
    "close_time": "2025-05-03T16:00:00Z",
    "profit": "175.00",
    "lot_size": "2.00"
  }
  ```

#### Partial Update

- **Request**  
  ```http
  PATCH /api/trade/a1b2c3d4-5678-90ab-cdef-1234567890ab/
  Content-Type: application/json
  Authorization: Bearer <token>

  {
    "profit": "200.00"
  }
  ```

- **Response (200 OK)**  
  ```json
  {
    "id": "a1b2c3d4-5678-90ab-cdef-1234567890ab",
    "user": "user1@example.com",
    "expert": "EA1234MAGIC",
    "open_time": "2025-05-03T14:00:00Z",
    "close_time": "2025-05-03T16:00:00Z",
    "profit": "200.00",
    "lot_size": "2.00"
  }
  ```

#### Delete a Trade (Not Allowed)

- **Request**  
  ```http
  DELETE /api/trade/a1b2c3d4-5678-90ab-cdef-1234567890ab/
  Authorization: Bearer <token>
  ```

- **Response (405 Method Not Allowed)**  
  ```json
  {
    "detail": "Method \"DELETE\" not allowed."
  }
  ```

### 3. Subscription Validation

```
GET /api/trade-auth/{magic_number}/
```

- **Request**  
  ```http
  GET /api/trade-auth/EA1234MAGIC/
  Authorization: Bearer <token>
  ```

- **Response (200 OK)**  
  ```json
  {
    "user": "user1@example.com",
    "expert": {
      "name": "EA1",
      "magic_number": "EA1234MAGIC",
      "version": "1.0"
    },
    "subscribed_at": "2025-04-15T12:00:00Z",
    "last_paid_at": "2025-04-20T12:00:00Z",
    "expires_at": "2025-06-15T12:00:00Z"
  }
  ```

- **Response (410 Gone)**  
  ```json
  {
    "detail": "Subscription expired"
  }
  ```
