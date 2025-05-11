# Market API

**Market API** is a Django app within the TradeVantage project that provides RESTful endpoints to manage Expert Advisors (EAs) and user subscriptions (ExpertUsers).

## Features

- **Expert Advisors**  
  - Full CRUD on ExpertAdvisor model  
  - Fields: magic_number, name, description, version, author, image_url, file_url, timestamps  
- **Subscriptions**  
  - Per-user subscriptions via ExpertUser model  
  - Automatic user assignment and duplicate-check prevention  
- **Filtering & Pagination**  
  - Filter by name, author, date range, download count  
  - Pagination with configurable page size  
- **Authentication & Permissions**  
  - JWT-based token authentication  
  - Users can only view or modify their own subscriptions  

## Models

### ExpertAdvisor
- **magic_number** (AutoField, PK)  
- **name** (CharField)  
- **description** (TextField)  
- **version** (CharField)  
- **author** (CharField)  
- **created_at**, **updated_at** (timestamps)  
- **image_url**, **file_url** (optional URL fields)  

### ExpertUser
- **id** (AutoField, PK)  
- **user** (FK to custom User)  
- **expert** (FK to ExpertAdvisor)  
- **subscribed_at**, **expires_at** (timestamps)  

## API Endpoints

### Expert Advisors
| Method | Endpoint               | Description               |
|--------|------------------------|---------------------------|
| GET    | `/api/experts/`        | List or search EAs        |
| GET    | `/api/experts/{id}/`   | Retrieve a single EA      |
| POST   | `/api/experts/`        | Create a new EA           |
| PUT    | `/api/experts/{id}/`   | Update an existing EA     |
| DELETE | `/api/experts/{id}/`   | Delete an EA              |

### Subscriptions (ExpertUser)
| Method | Endpoint                         | Description                                      |
|--------|----------------------------------|--------------------------------------------------|
| GET    | `/api/subscriptions/`            | List current user’s subscriptions                |
| GET    | `/api/subscriptions/{id}/`       | Retrieve a specific subscription                 |
| POST   | `/api/subscriptions/`            | Subscribe current user to an EA                  |
| PUT    | `/api/experts/{id}/`             | Update an subscription                           |
| DELETE | `/api/subscriptions/{id}/`       | Unsubscribe (delete) a subscription              |

## Filtering, Searching & Ordering

- **Search**: `?search=<keyword>` (name, author, description)  
- **Filter**:  
  - `/api/experts/?created_at_after=YYYY-MM-DD&created_at_before=YYYY-MM-DD`  
  - `/api/subscriptions/?expires_at_before=YYYY-MM-DD`  
- **Ordering**: `?ordering=created_at` or `?ordering=-download_count`  
- **Pagination**:  
  - `?page=<number>`  
  - `?page_size=<size>` (max 50 by default)  

## Authentication

- Uses **JWT** tokens via `djangorestframework-simplejwt`  
- Include header:  
  ```
  Authorization: Bearer <access_token>
  ```

## Admin

- Registered models: `ExpertAdvisor`, `ExpertUser`  
- Custom admin classes provide search, filtering, and list displays  

## Testing

- Run tests for Market API:
  ```bash
  python manage.py test market_api --keepdb
  ```


## Example JSON Responses

### Expert Advisors List
```json
{
    "count": 1,
    "next": null,
    "previous": null,
    "results": [
        {
            "magic_number": 1,
            "name": "Test EA",
            "description": "This is a test EA",
            "version": "1",
            "author": "Timmy Ifidon",
            "created_at": "2025-05-05T03:26:09.442261Z",
            "updated_at": "2025-05-05T03:26:09.442276Z",
            "image_url": "https://images.unsplash.com/photo-1502685104226-ee32379fefbe",
            "file_url": "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf"
        }
    ]
}
```

### Expert Advisor Detail
```json
{
  "magic_number": 1,
  "name": "Trend Sniper EA",
  "description": "A trend-following MT4 Expert Advisor",
  "version": "1.0",
  "author": "Stro Ifidon",
  "created_at": "2025-04-01T12:00:00Z",
  "updated_at": "2025-04-01T12:00:00Z",
  "image_url": "https://example.com/images/trend-sniper.png",
  "file_url": "https://example.com/files/trend-sniper.ex4"
}
```

### ExpertUser Detail
```json
{
  "id": 3,
  "user": "a1b2c3d4-e5f6-7a8b-9c0d-e1f2a3b4c5d6",
  "expert": 1,
  "subscribed_at": "2025-04-10T09:00:00Z",
  "last_paid_at": "2025-04-10T09:00:00Z",
  "expires_at": "2025-05-10T09:00:00Z"
}
```

## URL Patterns (JSON Format)

```json
{
  "ExpertAdvisorViewSet": {
    "list": "/api/experts/",
    "create": "/api/experts/",
    "retrieve": "/api/experts/{magic_number}/",
    "update": "/api/experts/{magic_number}/",
    "partial_update": "/api/experts/{magic_number}/",
    "destroy": "/api/experts/{magic_number}/"
  },
  "ExpertUserViewSet": {
    "list": "/api/subscriptions/",
    "create": "/api/subscriptions/",
    "retrieve": "/api/subscriptions/{id}/",
    "update": "/api/subscriptions/{id}/",
    "partial_update": "/api/subscriptions/{id}/",
    "destroy": "/api/subscriptions/{id}/"
  }
}
```
