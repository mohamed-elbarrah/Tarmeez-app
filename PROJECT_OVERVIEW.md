# 🏗️ Tarmeez — نظرة عامة على المشروع

> **Version:** 1.0.0 | **Created:** 2026-03-16 | **Architecture:** Multi-tenant SaaS + TimescaleDB Analytics

---

## 📋 Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Architecture](#2-system-architecture)
3. [Data Models Overview](#3-data-models-overview)
4. [Security Measures](#4-security-measures)
5. [Key Features](#5-key-features)
6. [Deployment Guide](#6-deployment-guide)
7. [API Quick Reference](#7-api-quick-reference)
8. [Testing Strategy](#8-testing-strategy)
9. [Known Issues & Limitations](#9-known-issues--limitations)
10. [Future Roadmap](#10-future-roadmap)

---

## 1. Executive Summary

**Tarmeez** (ترميز) is a **multi-tenant SaaS e-commerce platform** that enables merchants to create and manage their own online stores through a white-label storefront system. The platform is designed for the Arab market with full Arabic RTL support, Arabic UI labels, and Saudi Riyal (SAR) pricing.

The platform operates on three distinct user levels: a **Superadmin** who controls merchant approvals and platform settings; **Merchants** who manage their individual stores with full product, order, and analytics capabilities; and **Customers** who shop across multiple merchant storefronts through isolated, branded experiences.

Analytics is a first-class citizen of the platform — each storefront automatically injects a lightweight (< 5KB) vanilla JavaScript tracker that collects anonymous behavioral data (page views, clicks, scrolls, cart events) and sends it to a dedicated **TimescaleDB** time-series database. This data is pre-aggregated hourly and daily via NestJS cron jobs, then exposed through 7 analytics endpoints that feed a rich dashboard with area charts, pie charts, bar charts, funnel visualization, and canvas-based heatmaps — all privacy-compliant with zero PII storage.

---

## 2. System Architecture

### High-Level Architecture

```mermaid
graph TB
    subgraph "Client (Next.js 16)"
        LP[Landing Page]
        MD[Merchant Dashboard]
        SA[Superadmin Panel]
        SF[Storefront]
        TR[Tracker Script<br/>tarmeez-tracker.js]
    end

    subgraph "API (NestJS 11 — Port 8000)"
        AUTH[Auth Module]
        MERCH[Merchant Module]
        STORE[Stores Module]
        PROD[Products Module]
        ORD[Orders Module]
        ANA[Analytics Module]
        CRON[Aggregation Cron]
        SA_MOD[Superadmin Module]
    end

    subgraph "Databases"
        PG[(PostgreSQL<br/>Port 5432<br/>Main DB)]
        TS[(TimescaleDB<br/>Port 5433<br/>Analytics DB)]
    end

    LP --> AUTH
    MD --> MERCH
    MD --> PROD
    MD --> ORD
    MD --> ANA
    SA --> SA_MOD
    SF --> STORE
    SF --> ORD
    TR --> ANA

    AUTH --> PG
    MERCH --> PG
    STORE --> PG
    PROD --> PG
    ORD --> PG
    SA_MOD --> PG

    ANA --> TS
    ANA --> PG
    CRON --> TS
    CRON --> PG
```

### Technology Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Frontend Framework | Next.js | 16.1.5 |
| UI Library | React | 19.2.3 |
| Styling | Tailwind CSS | v4 |
| UI Components | shadcn/ui (Radix UI) | latest |
| Charts | Recharts (via shadcn) | ^2.15.4 |
| State Management | Redux Toolkit + RTK Query | ^2.11.2 |
| Backend Framework | NestJS | ^11.0.1 |
| ORM | Prisma | ^5.22.0 |
| Main Database | PostgreSQL | 15+ |
| Analytics Database | TimescaleDB | 2.x |
| Authentication | JWT (access + refresh) | — |
| Language | TypeScript | ^5 |
| Package Manager | npm | — |

### Communication Patterns

| Pattern | Usage |
|---------|-------|
| REST (JSON) | All API communication |
| HTTP Cookies | JWT token transport |
| `navigator.sendBeacon` | Analytics event collection (non-blocking) |
| RTK Query polling (60s) | Analytics data refresh |
| NestJS `@Cron` | Background data aggregation |
| In-memory buffer + batch flush (10s) | Analytics write optimization |

---

## 3. Data Models Overview

### Core Entity Relationships

```mermaid
erDiagram
    User {
        uuid id PK
        string email
        string password
        UserRole role
        uuid storeId FK
    }
    Merchant {
        uuid id PK
        uuid userId FK
        string storeName
        string storeSlug
        MerchantStatus status
    }
    Store {
        uuid id PK
        uuid merchantId FK
        string slug
        string primaryColor
        string[] enabledPaymentMethods
    }
    Product {
        uuid id PK
        uuid storeId FK
        string name
        float price
        ProductStatus status
    }
    Order {
        uuid id PK
        string orderCode
        uuid storeId FK
        decimal total
        OrderStatus status
    }
    Customer {
        uuid id PK
        uuid storeId FK
        uuid userId FK
    }

    User ||--o| Merchant : "platform user"
    User ||--o{ Customer : "storefront identity"
    Merchant ||--|| Store : "owns"
    Store ||--o{ Product : "sells"
    Store ||--o{ Order : "receives"
    Store ||--o{ Customer : "serves"
    Product ||--o{ Order : "purchased in"
    Customer ||--o{ Order : "places"
```

### Analytics Data Model

```mermaid
graph LR
    subgraph "Raw Data (Hypertables — write-only)"
        PV[page_views<br/>time, storeId, sessionId<br/>pageSlug, device, country]
        AE[analytics_events<br/>time, storeId, type<br/>CART_ADD | PRODUCT_VIEW ...]
        HM[heatmap_data<br/>time, storeId, x%, y%<br/>CLICK | MOVE | SCROLL]
    end

    subgraph "Aggregated (Regular tables — read-only)"
        AH[analytics_hourly<br/>pageViews, uniqueVisitors<br/>cartAdds, checkoutStarts]
        AD[analytics_daily<br/>pageViews, uniqueVisitors<br/>sources, countries, topPages]
    end

    PV -->|@Cron 0* * * *| AH
    AE -->|@Cron 0* * * *| AH
    PV -->|@Cron 0 0 * * *| AD
    AE -->|@Cron 0 0 * * *| AD
```

---

## 4. Security Measures

### Authentication

| Measure | Implementation |
|---------|---------------|
| Password hashing | bcryptjs with salt rounds = 10 |
| Access tokens | JWT, 15-minute expiry, HTTP-only cookie |
| Refresh tokens | JWT, 7-day expiry, HTTP-only cookie, hashed in DB |
| Token rotation | New refresh token issued on every refresh request |
| Platform vs. Customer tokens | Separate cookie names (`access_token` vs `customer_access_token`) prevent cross-context auth |

### Authorization

| Measure | Implementation |
|---------|---------------|
| Role-based access | `SUPERADMIN`, `MERCHANT`, `CUSTOMER` roles enforced by guards |
| Multi-tenant isolation | Every merchant query filtered by `storeId` resolved from JWT |
| Cross-store prevention | Analytics queries enforce `WHERE storeId = merchant.storeId` |
| Middleware route protection | Next.js middleware checks cookie presence before rendering protected routes |

### API Security

| Measure | Implementation |
|---------|---------------|
| Rate limiting | `ThrottlerModule` — global limit + 100 req/min for analytics collect |
| Input validation | `ValidationPipe` with `whitelist: true` and `forbidNonWhitelisted: true` |
| CORS | Restricted to `CLIENT_URL` environment variable only |
| File upload restrictions | Allowed types: jpg, jpeg, png, svg, ico, webp; Max size: 2MB |
| Analytics payload size | Max 2KB per collect request |

### Privacy (GDPR/PDPL Compliance)

| Measure | Implementation |
|---------|---------------|
| No PII storage | IP addresses resolved to country code and immediately discarded |
| Anonymous sessions | UUIDs generated with `crypto.getRandomValues`, stored in `sessionStorage` only |
| No cookies in tracker | Tracker uses `sessionStorage` exclusively (cleared on tab close) |
| No full referrer URLs | Only referrer domain is recorded (not full URL with query params) |
| Data retention | Raw analytics data: 90-day retention policy |

### Input Security

```typescript
// DTO validation — injection prevention
@IsEmail()                    // ensures valid email format
@IsString() @MaxLength(255)   // prevents oversized inputs
@IsUUID()                     // enforces UUID format for IDs
@IsEnum(OrderStatus)          // whitelist-only enum values
```

---

## 5. Key Features

### 1. 🏪 Multi-Tenant Store Builder
Each merchant gets a fully isolated storefront at `/store/[storeSlug]`. Stores have custom branding (logo, colors, fonts, border radius), domain support, and theme selection. A single platform hosts unlimited stores.

### 2. 📊 Full-Stack Analytics System
A complete behavioral analytics suite with a tracker script, TimescaleDB pipeline, hourly/daily aggregation, and 6-tab dashboard (Overview, Traffic, Sales, Pages, Funnel, Heatmap). Real-time polling every 60 seconds.

### 3. 🔐 Dual Authentication System
Platform users (merchants/admins) and storefront customers have completely separate authentication flows with independent JWT cookies, refresh mechanisms, and session management.

### 4. 🛒 Complete E-Commerce Engine
Full product management with variants (size, color, etc.), bundle pricing offers, category organization, inventory tracking, and a complete checkout-to-delivery order lifecycle.

### 5. 🎨 Visual Page Builder
Drag-and-drop page builder powered by **Puck editor** (`@puckeditor/core`) allowing merchants to create landing pages, policy pages, and custom content without coding.

### 6. 📈 Sales Analytics from Orders
Revenue and conversion metrics are calculated directly from the `Order` model (not duplicated in analytics tables), ensuring financial data accuracy and consistency.

### 7. 🔥 Heatmap Visualization
Click, mouse movement, and scroll depth data collected at percentage coordinates (device-responsive) and rendered as canvas overlays, with separate views for mobile vs desktop users.

### 8. 👑 Merchant Approval Workflow
New merchants submit an application and go through a PENDING → ACTIVE approval gate managed by superadmins. Rejected merchants receive a REJECTED status and cannot access the dashboard.

### 9. 🌍 Arabic-First RTL Platform
Built for the Arab market: `dir="rtl"`, Cairo font family, Arabic labels in analytics funnel steps, SAR currency, and RTL-aware Tailwind CSS utilities.

### 10. ⚡ Performance-First Architecture
- Analytics: Fire-and-forget sendBeacon + in-memory buffer + batch DB writes
- Dashboard: Pre-aggregated data only (never raw hypertable scans)
- Tracker: < 5KB, async load, no blocking, no dependencies
- API: RTK Query caching + 60s polling (no unnecessary requests)

---

## 6. Deployment Guide

### Prerequisites

```bash
# Required software
Node.js >= 20 LTS
PostgreSQL >= 15
TimescaleDB >= 2.x (installed as PostgreSQL extension)
npm >= 10
```

### Local Development Setup

#### 1. Clone & Install

```bash
git clone <repo-url> tarmeez
cd tarmeez

# Install root dependencies
npm install

# Install client dependencies
cd client && npm install && cd ..

# Install server dependencies
cd server && npm install && cd ..
```

#### 2. Database Setup

```bash
# Create main database (PostgreSQL)
createdb tarmeez

# Create analytics database (TimescaleDB)
createdb tarmeez_analytics

# Enable TimescaleDB extension on analytics DB
psql tarmeez_analytics -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"

# Convert raw tables to hypertables (after migration)
psql tarmeez_analytics -c "
  SELECT create_hypertable('page_views', 'time', if_not_exists => TRUE);
  SELECT create_hypertable('analytics_events', 'time', if_not_exists => TRUE);
  SELECT create_hypertable('heatmap_data', 'time', if_not_exists => TRUE);
"

# Set retention policy (90 days for raw data)
psql tarmeez_analytics -c "
  SELECT add_retention_policy('page_views', INTERVAL '90 days');
  SELECT add_retention_policy('analytics_events', INTERVAL '90 days');
  SELECT add_retention_policy('heatmap_data', INTERVAL '90 days');
"
```

#### 3. Environment Configuration

```bash
# server/.env
DATABASE_URL="postgresql://postgres:password@localhost:5432/tarmeez"
ANALYTICS_DATABASE_URL="postgresql://postgres:password@localhost:5433/tarmeez_analytics"
JWT_ACCESS_SECRET="generate-with-openssl-rand-base64-64"
JWT_REFRESH_SECRET="generate-with-openssl-rand-base64-64"
CLIENT_URL="http://localhost:3000"
PORT=8000
SERVER_URL="http://localhost:8000"
NODE_ENV="development"

# client/.env.local
NEXT_PUBLIC_API_URL="http://localhost:8000/api"
```

#### 4. Database Migrations & Seeding

```bash
cd server

# Run main database migration
npx prisma migrate deploy --schema=prisma/schema.prisma

# Run analytics database migration
npx prisma migrate deploy --schema=prisma/analytics.prisma

# Generate Prisma clients
npx prisma generate --schema=prisma/schema.prisma
npx prisma generate --schema=prisma/analytics.prisma

# Seed demo data (optional)
npm run seed:demo
```

#### 5. Start Development Servers

```bash
# Terminal 1: Start server
cd server
npm run start:dev        # NestJS with hot reload

# Terminal 2: Start client
cd client
npm run dev              # Next.js dev server on port 3000
```

#### 6. Create First Superadmin

```bash
# Direct database insert (no registration endpoint for superadmin)
cd server
npx prisma studio        # Opens GUI at http://localhost:5555
# OR use psql to insert a SUPERADMIN user
```

### Production Deployment

#### Server (NestJS)

```bash
cd server

# Build
npm run build

# Run production
npm run start:prod
# OR with PM2:
pm2 start dist/main.js --name tarmeez-api
```

#### Client (Next.js)

```bash
cd client

# Build
npm run build

# Start production server
npm run start
# OR deploy to Vercel/Netlify (recommended)
```

#### Production Environment Checklist

```bash
# Security
JWT_ACCESS_SECRET=<64+ char random string>
JWT_REFRESH_SECRET=<64+ char random string>
NODE_ENV=production

# Database
DATABASE_URL=<production PostgreSQL connection string>
ANALYTICS_DATABASE_URL=<production TimescaleDB connection string>

# CORS
CLIENT_URL=https://yourdomain.com

# Server
PORT=8000
SERVER_URL=https://api.yourdomain.com
```

#### Reverse Proxy (Nginx)

```nginx
# API server
server {
    listen 443 ssl;
    server_name api.yourdomain.com;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

# Client (if self-hosted)
server {
    listen 443 ssl;
    server_name yourdomain.com;

    location / {
        proxy_pass http://localhost:3000;
    }
}
```

---

## 7. API Quick Reference

### Authentication

```bash
# تسجيل دخول التاجر
curl -X POST http://localhost:8000/api/auth/platform/login \
  -H "Content-Type: application/json" \
  -d '{"email":"merchant@example.com","password":"password123"}' \
  -c cookies.txt

# التحقق من الجلسة الحالية
curl http://localhost:8000/api/auth/me \
  -b cookies.txt

# تسجيل الخروج
curl -X POST http://localhost:8000/api/auth/logout \
  -b cookies.txt
```

### Merchant Operations

```bash
# جلب بيانات المتجر
curl http://localhost:8000/api/merchant/me -b cookies.txt

# جلب قائمة المنتجات
curl http://localhost:8000/api/merchant/products -b cookies.txt

# إنشاء منتج جديد
curl -X POST http://localhost:8000/api/merchant/products \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{
    "name": "قميص قطني",
    "price": 120,
    "slug": "qamees-qutni",
    "status": "ACTIVE",
    "images": ["https://example.com/image.jpg"]
  }'

# جلب الطلبات
curl "http://localhost:8000/api/merchant/orders?page=1&limit=20" -b cookies.txt

# تحديث حالة طلب
curl -X PATCH http://localhost:8000/api/merchant/orders/ORD-12345/status \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{"status":"CONFIRMED"}'
```

### Storefront (Public)

```bash
# الحصول على بيانات المتجر
curl http://localhost:8000/api/stores/my-store-slug

# إنشاء طلب شراء
curl -X POST http://localhost:8000/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "storeSlug": "my-store",
    "items": [{"productId": "uuid", "quantity": 2}],
    "customerName": "أحمد محمد",
    "customerPhone": "0501234567",
    "shippingCity": "الرياض",
    "shippingRegion": "الرياض",
    "shippingStreet": "شارع الملك فهد",
    "paymentMethod": "cash_on_delivery"
  }'

# تتبع طلب
curl "http://localhost:8000/api/orders/ORD-12345?storeSlug=my-store"
```

### Analytics

```bash
# نظرة عامة على التحليلات (آخر 7 أيام)
curl "http://localhost:8000/api/merchant/analytics/overview?period=7d" -b cookies.txt

# مصادر الزيارات
curl "http://localhost:8000/api/merchant/analytics/traffic?period=30d" -b cookies.txt

# قمع التحويل
curl "http://localhost:8000/api/merchant/analytics/funnel?period=7d" -b cookies.txt

# تحليل المبيعات
curl "http://localhost:8000/api/merchant/analytics/sales?period=30d" -b cookies.txt

# خريطة الحرارة للنقرات
curl "http://localhost:8000/api/merchant/analytics/heatmap?page=/&type=CLICK&device=DESKTOP" -b cookies.txt

# إرسال حدث تتبع (يستخدمه السكريبت فقط — navigator.sendBeacon)
curl -X POST http://localhost:8000/api/analytics/collect \
  -H "Content-Type: application/json" \
  -d '{
    "storeRef": "store-uuid-or-slug",
    "sessionId": "anonymous-session-id",
    "type": "pageview",
    "page": "/products",
    "device": "desktop",
    "ts": 1710000000000
  }'
```

### Superadmin

```bash
# عرض طلبات التجار المعلقة
curl "http://localhost:8000/api/superadmin/merchants?status=PENDING" -b cookies.txt

# الموافقة على تاجر
curl -X PATCH http://localhost:8000/api/superadmin/merchants/merchant-uuid/approve \
  -b cookies.txt

# رفض تاجر
curl -X PATCH http://localhost:8000/api/superadmin/merchants/merchant-uuid/reject \
  -b cookies.txt \
  -H "Content-Type: application/json" \
  -d '{"reason": "Insufficient information provided"}'
```

---

## 8. Testing Strategy

### Current Test Coverage

| Module | Test Type | Files |
|--------|----------|-------|
| App Controller | Unit | `src/app.controller.spec.ts` |
| E2E | Integration | `test/app.e2e-spec.ts` |

### Running Tests

```bash
cd server

# Unit tests
npm run test

# Unit tests with watch mode
npm run test:watch

# Coverage report
npm run test:cov

# E2E tests
npm run test:e2e
```

### Testing Architecture (NestJS)

```typescript
// Unit test pattern
describe('AuthService', () => {
  let service: AuthService

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: JwtService, useValue: mockJwt },
      ],
    }).compile()

    service = module.get<AuthService>(AuthService)
  })

  it('should hash password on registration', async () => {
    // test implementation
  })
})
```

### Recommended Testing Additions

| Priority | Test | Description |
|----------|------|-------------|
| High | Auth service unit tests | Login, register, refresh, logout |
| High | Order service unit tests | createOrder, stock validation |
| High | Analytics collect E2E | POST /analytics/collect → DB write |
| High | Merchant guard tests | Role enforcement |
| Medium | Analytics query unit tests | Period calculations, trend math |
| Medium | Aggregation service unit tests | Hourly/daily compute accuracy |
| Medium | Product CRUD E2E | Full create/update/delete cycle |
| Low | Heatmap data E2E | Click collection + retrieval |

### Client Testing (Recommended Setup)

```bash
# Install testing dependencies
cd client
npm install --save-dev jest @testing-library/react @testing-library/jest-dom

# Test individual components
npx jest components/pages/merchant/analytics/formatters.test.ts
```

---

## 9. Known Issues & Limitations

### Current Limitations

| Area | Issue | Impact |
|------|-------|--------|
| **Analytics** | Bounce rate always returns `0` — not yet calculated | Medium — dashboard shows 0% bounceRate |
| **Analytics** | Heatmap requires minimum 100 data points — new stores see "insufficient data" | Low |
| **Coupons** | UI is fully built but backend API is not yet implemented | Medium — coupon feature non-functional |
| **Abandoned Cart** | UI is built but tracking/recovery emails not implemented | Medium |
| **Team Management** | UI built but backend endpoints not implemented | Low |
| **Billing** | UI built but no payment gateway integration for subscriptions | High — billing is not functional |
| **Custom Domains** | `domainStatus` field exists but domain verification not implemented | Medium |
| **Email Notifications** | No email sending configured — order confirmations not sent | High |
| **Analytics History** | First store approval generates no historical data — charts start empty | Low |
| **Superadmin Dashboard** | UI shows placeholder metrics — real platform stats not yet queried | Medium |

### Technical Debt

| Item | Description |
|------|-------------|
| Image Storage | Currently uses local disk (`uploads/`) — not suitable for multi-server production |
| No Redis Cache | Analytics responses not cached in Redis (in-memory only) |
| Single Payment Gateway | Only Cash on Delivery implemented; no online payment |
| Missing DTOs | Some endpoints use partial DTO validation |
| No API Documentation | No Swagger/OpenAPI documentation generated |

---

## 10. Future Roadmap

### Short-term (Next 3 months)

| Feature | Description |
|---------|-------------|
| 📧 Email Notifications | Order confirmation, abandoned cart recovery, merchant approval |
| 💳 Online Payments | Integrate PayTabs or Stripe for Saudi market |
| 🗄️ Cloud Storage | Replace local disk with S3-compatible storage (Cloudflare R2) |
| 📋 Coupon Backend | Backend implementation for coupon creation and validation at checkout |
| 📊 Real Bounce Rate | Calculate bounce rate from session data in aggregation |
| 🔍 Swagger API Docs | Auto-generate OpenAPI documentation for all endpoints |

### Medium-term (3-6 months)

| Feature | Description |
|---------|-------------|
| 🔔 Push Notifications | Browser push for order status updates |
| 📱 Mobile App | React Native companion app for merchants |
| 🤖 AI Product Descriptions | OpenAI integration for product SEO content |
| 📦 Shipping Integrations | Aramex, SMSA, Fetchr API integrations |
| 💰 Subscription Plans | Implement plan tiers with feature gating |
| 🌐 Multi-language | English UI support alongside Arabic |
| 📈 Advanced Analytics | Cohort analysis, customer lifetime value |

### Long-term (6-12 months)

| Feature | Description |
|---------|-------------|
| 🏪 App Marketplace | Third-party developer ecosystem with installable apps |
| 🎨 Custom Theme Builder | Low-code theme customization beyond color/font |
| 📊 Revenue Analytics | Platform-level merchant revenue reporting for superadmin |
| 🔗 Webhooks | Outgoing webhooks for order events, inventory changes |
| 🛡️ Fraud Detection | ML-based unusual order pattern detection |
| 🌍 Multi-region | Deploy in multiple cloud regions for latency reduction |

---

## Cross-References

- For detailed client implementation: [client/CLIENT_DOCUMENTATION.md](client/CLIENT_DOCUMENTATION.md)
- For detailed server implementation: [server/SERVER_DOCUMENTATION.md](server/SERVER_DOCUMENTATION.md)
- For analytics and engineering rules: [AGENTS.md](AGENTS.md)
