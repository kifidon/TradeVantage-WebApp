MT4 Expert Advisor Hub

Tagline: A cloud‑native web platform for distributing MT4 Expert Advisors (EAs) and visualising monthly trading performance – built entirely on free‑tier services to showcase modern Cloud / DevOps skills.

📌 Feature Set

Area

Capability

Landing

Marketing About page with CTA Start Now → Register/Login

Auth

Supabase Auth (email / OAuth) – JWT tokens consumed by React + Axios

Dashboard

• Monthly KPIs: total trades, wins, losses, net profit

           • Breakdown per‑EA  
           • Responsive graphs (Recharts) & summary cards |

| Market | Browse all EAs, filter/search, link cards → /experts/{magicNumber} |
| EA Detail | Hero image, description, download instructions, direct .ex4 link |
| API | Django REST Framework CRUD endpoints protected by JWT |
| DevOps | Dockerised services, GitHub Actions CI/CD, K8s (K3s) on Civo Free |

🏗️ Architecture Overview

┌──────────────────────────────┐       ┌───────────────────────────┐
│        React Front‑End       │ ----> │  Django REST API (JWT)    │
│  • Vite + Axios              │       │  • DRF                    │
│  • Recharts / Headless UI    │       │  • Celery (optional)      │
└──────────────────────────────┘       │  • Supabase Postgres      │
            ▲ ▲                         └────────┬──────────────────┘
            │ └────────────GraphQL (future)──────┘
            │
            └── Auth / Storage  ←––––  Supabase  (Free Tier)

All components are containerised and deployed via a lightweight K3s cluster (Civo or Okteto free tier).

🛣️ Roadmap

Phase

Goal

Milestones

0

Project Bootstrap

Repo init · Issue templates · Pre‑commit hooks

1

Data Model & API

Supabase schema · Django models · CRUD endpoints

2

Auth & Landing

Supabase auth · About page · Register/Login flow

3

Dashboard MVP

Axios client · Monthly summary query · Recharts graphs

4

Market & Detail

EA catalogue · /experts/{magicNumber} page

5

CI/CD Pipeline

GitHub Actions build → Docker Hub push

6

K8s Deployment

Helm chart · Ingress · TLS via Let’s Encrypt

7

Observability

Grafana Cloud (free) · Loki logs · Prometheus metrics

8

Polish & Docs

README badges · Screenshots · Video demo

🗄️ Database Design (Supabase / Postgres)

erDiagram
    users ||--o{ expert_users : "owns"
    users {
      uuid id PK
      text email
      text full_name
    }

    expert_advisors ||--o{ trades : "has"
    expert_advisors {
      int  id PK  "magicNumber"
      text title
      text description
      text image_url
      text file_url
      timestamptz created_at
    }

    expert_users {
      int id PK
      uuid user_id FK
      int expert_id FK
      timestamptz subscribed_at
    }

    trades {
      bigint id PK
      int expert_id FK
      uuid user_id FK
      timestamptz open_time
      timestamptz close_time
      numeric profit
      numeric lot_size
    }

Monthly KPIs are served via a DB materialised view v_monthly_stats for fast reads.

🛍️ Market Page & Catalog Workflow

Element

Detail

Route

/market (public) – grid/list of all EAs

UI

Card per EA → image, title, subtitle, “View” CTA

Filters

Text search (title, magicNumber), profit range slider, category tags (future)

Sorting

Default: newest; options: most‑downloaded, highest win‑rate

Call‑to‑Action

Clicking a card → /experts/{magicNumber}

Data Source

GET /api/experts/ – paginated JSON from Django REST Framework

Caching

React Query (stale‑while‑revalidate) or SWR for instant UX

Analytics

Track downloads/events via Supabase analytics table (optional)

Note: This page is static‑rendered in React and hydrated via Axios. For SEO you may add prerendering with Vite‑SSR, but not mandatory for MVP.

📂 Repository Layout

cloud-ea-hub/
│  README.md
│  docker-compose.yml          # Local dev
│  kube/                       # Helm chart & manifests
├─ frontend/                   # React (Vite)
│   ├─ src/api/axios.ts
│   └─ …
└─ backend/
    ├─ Dockerfile
    ├─ requirements.txt
    ├─ config/settings.py
    └─ app/
        ├─ experts/
        ├─ trades/
        └─ …

🐳 Containerisation Steps

Frontend

FROM node:20-alpine
WORKDIR /app
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ .
RUN npm run build
CMD ["npx", "serve", "-s", "dist", "-l", "80"]

Backend

FROM python:3.12-slim
WORKDIR /srv
COPY backend/requirements.txt ./
RUN pip install -r requirements.txt
COPY backend/ .
CMD ["gunicorn", "config.wsgi:application", "-b", "0.0.0.0:8000"]

docker-compose.yml (dev) – services: frontend, backend, traefik (reverse proxy).

☸️ Kubernetes (K3s) High‑Level Workflow

Step

Tool

Action

1

k3sup

Bootstrap K3s cluster on Civo (free credits)

2

Helm

helm install ea-hub ./kube/chart

3

Ingress‑NGINX

TLS via cert‑manager + Let’s Encrypt

4

Secrets

Supabase keys stored in K8s Secret objects

5

GitHub Actions

On push → Build images → Push to Docker Hub → kubectl rollout restart

Total free usage fits within Civo’s $250 trial or Okteto’s always‑free tier.

🔄 GitHub Actions CI/CD (simplified)

name: CI
on: [push]
jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - name: Build & push images
        run: |
          docker build -t $REGISTRY/frontend:$SHA frontend
          docker build -t $REGISTRY/backend:$SHA backend
          echo $PASS | docker login -u $USER --password-stdin $REGISTRY
          docker push $REGISTRY/frontend:$SHA
          docker push $REGISTRY/backend:$SHA
      - name: Deploy to K8s
        env:
          KUBECONFIG: ${{ secrets.KUBECONFIG }}
        run: |
          kubectl set image deploy/frontend frontend=$REGISTRY/frontend:$SHA
          kubectl set image deploy/backend backend=$REGISTRY/backend:$SHA

💰 Free‑Tier Cost Table

Service

Free Allocation

Notes

Supabase

500 MB DB · 2 GB storage

Auth, Postgres, Storage

Civo K3s

$250 credits (≈3 mo)

Or use Okteto always‑free

GitHub Actions

2,000 CI minutes/mo

Public repos unlimited

Docker Hub

1 private / unlimited public repos



Grafana Cloud

10k series logs & metrics

Observability

🗒️ TODO Checklist (Quick‑Start)



📜 License

MIT License © 2025 Your Name

