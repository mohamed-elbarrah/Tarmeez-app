# 🖥️ Tarmeez Server — توثيق شامل للخادم

> **Version:** 1.0.0 | **Created:** 2026-03-16 | **Framework:** NestJS 11 + Prisma + PostgreSQL/TimescaleDB

---

## 📋 Table of Contents

1. [Project Overview](#1-project-overview)
2. [Project Structure](#2-project-structure)
3. [Database Schema](#3-database-schema)
4. [API Endpoints Reference](#4-api-endpoints-reference)
5. [Authentication & Authorization](#5-authentication--authorization)
6. [Business Logic](#6-business-logic)
7. [Analytics System](#7-analytics-system)
8. [Background Jobs](#8-background-jobs)
9. [Configuration](#9-configuration)
10. [Dependencies](#10-dependencies)
11. [Data Flow](#11-data-flow)
12. [Error Handling](#12-error-handling)

---

## 1. Project Overview

Tarmeez Server is a **NestJS 11** REST API serving a multi-tenant SaaS e-commerce platform. It uses two databases:

| Database | Type | Port | Purpose |
|----------|------|------|---------|
| Main DB | PostgreSQL | 5432 | Core business data (stores, orders, products) |
| Analytics DB | TimescaleDB (PostgreSQL) | 5433 | Time-series analytics data |

The API is prefixed with `/api` and runs on **port 8000** by default.

---

## 2. Project Structure

```
server/
├── prisma/
│   ├── schema.prisma           # Main database schema (stores, orders, products)
│   └── analytics.prisma        # Analytics database schema (TimescaleDB)
│
├── src/
│   ├── main.ts                 # Bootstrap: CORS, cookie-parser, ValidationPipe
│   ├── app.module.ts           # Root module — imports all feature modules
│   ├── app.controller.ts       # Root controller (health check)
│   ├── app.service.ts          # Root service
│   │
│   ├── prisma/                 # Database connection module
│   │   ├── prisma.module.ts    # Global PrismaModule
│   │   ├── prisma.service.ts   # Main DB PrismaClient
│   │   └── seed-store.ts       # Store seeding script
│   │
│   ├── auth/                   # Authentication module
│   │   ├── auth.module.ts
│   │   ├── auth.controller.ts  # Login, register, refresh, logout endpoints
│   │   ├── auth.service.ts     # JWT generation, bcrypt hashing, token management
│   │   ├── strategies/
│   │   │   ├── jwt-access.strategy.ts   # Passport JWT strategy (access token)
│   │   │   └── jwt-refresh.strategy.ts  # Passport JWT strategy (refresh token)
│   │   ├── guards/
│   │   │   ├── jwt-auth.guard.ts     # Standard JWT guard
│   │   │   ├── jwt-refresh.guard.ts  # Refresh token guard
│   │   │   ├── customer.guard.ts     # Customer-specific auth guard
│   │   │   └── roles.guard.ts        # Role-based access guard
│   │   └── decorators/
│   │       ├── current-user.decorator.ts  # @CurrentUser() param decorator
│   │       └── roles.decorator.ts         # @Roles() metadata decorator
│   │
│   ├── merchant/               # Merchant management module
│   │   ├── merchant.module.ts
│   │   ├── merchant.controller.ts   # /merchant/* endpoints
│   │   ├── merchant.service.ts      # Merchant business logic
│   │   ├── guards/
│   │   │   └── merchant.guard.ts    # Merchant-only access guard
│   │   └── dto/
│   │       └── update-store.dto.ts  # Store update payload
│   │
│   ├── stores/                 # Public storefront data module
│   │   ├── stores.module.ts
│   │   ├── stores.controller.ts  # /stores/* public endpoints
│   │   └── stores.service.ts     # Store data retrieval
│   │
│   ├── products/               # Product management module
│   │   ├── products.module.ts
│   │   ├── products.controller.ts  # /merchant/products/* endpoints
│   │   ├── products.service.ts     # Product CRUD + variants + offers
│   │   └── dto/
│   │       ├── create-product.dto.ts
│   │       ├── update-product.dto.ts
│   │       └── create-offer.dto.ts
│   │
│   ├── orders/                 # Order management module
│   │   ├── orders.module.ts
│   │   ├── orders.controller.ts  # /orders/* endpoints
│   │   ├── orders.service.ts     # Order creation, tracking
│   │   ├── dto/
│   │   │   └── create-order.dto.ts
│   │   └── utils/
│   │       └── order-code.util.ts  # Unique order code generator
│   │
│   ├── categories/             # Category management module
│   │   ├── categories.module.ts
│   │   ├── categories.controller.ts
│   │   ├── categories.service.ts
│   │   └── dto/
│   │       ├── create-category.dto.ts
│   │       └── update-category.dto.ts
│   │
│   ├── customer/               # Customer profile module
│   │   ├── customer.module.ts
│   │   ├── customer.controller.ts  # /customer/* endpoints
│   │   ├── customer.service.ts     # Profile, addresses, payment methods
│   │   └── dto/
│   │       ├── create-address.dto.ts
│   │       ├── update-address.dto.ts
│   │       ├── create-payment-method.dto.ts
│   │       └── update-profile.dto.ts
│   │
│   ├── reviews/                # Product review module
│   │   ├── reviews.module.ts
│   │   ├── reviews.controller.ts
│   │   ├── reviews.service.ts
│   │   └── dto/
│   │       └── create-review.dto.ts
│   │
│   ├── pages/                  # Custom page (page builder) module
│   │   ├── pages.module.ts
│   │   ├── pages.controller.ts
│   │   ├── pages.service.ts
│   │   └── dto/
│   │       ├── create-page.dto.ts
│   │       ├── update-page.dto.ts
│   │       └── update-page-status.dto.ts
│   │
│   ├── payments/               # Payment gateway module
│   │   ├── payments.module.ts
│   │   ├── payment.registry.ts    # Gateway registry pattern
│   │   └── gateways/
│   │       ├── base.gateway.ts          # Abstract base gateway
│   │       └── cash-on-delivery.gateway.ts  # COD implementation
│   │
│   ├── analytics/              # Analytics module (separate DB)
│   │   ├── analytics.module.ts
│   │   ├── analytics.controller.ts        # POST /analytics/collect
│   │   ├── merchant-analytics.controller.ts  # GET /merchant/analytics/*
│   │   ├── analytics.service.ts           # Event processing + store resolution
│   │   ├── analytics-prisma.service.ts    # Analytics DB Prisma client
│   │   ├── analytics-query.service.ts     # All analytics query methods
│   │   ├── aggregation.service.ts         # Cron-based aggregation
│   │   ├── geo.service.ts                 # IP → Country lookup (geoip-country)
│   │   └── dto/
│   │       └── collect-event.dto.ts
│   │
│   ├── superadmin/             # Platform administration module
│   │   ├── superadmin.module.ts
│   │   ├── superadmin.controller.ts  # /superadmin/* endpoints
│   │   ├── superadmin.service.ts     # Merchant approval workflow
│   │   └── guards/
│   │       └── superadmin.guard.ts   # SUPERADMIN role guard
│   │
│   └── utils/
│       └── slug.util.ts              # URL slug generation helper
│
├── scripts/
│   ├── seed-demo.ts            # Demo data seeder
│   └── check-timescale.js      # TimescaleDB connectivity check
│
└── package.json
```

---

## 3. Database Schema

### 3.1 Main Database (PostgreSQL — schema.prisma)

#### Enums

```sql
-- أدوار المستخدمين
UserRole: SUPERADMIN | MERCHANT | CUSTOMER

-- حالة التاجر (دورة الموافقة)
MerchantStatus: PENDING | ACTIVE | REJECTED

-- حالة المنتج
ProductStatus: DRAFT | ACTIVE | ARCHIVED

-- حالة العميل
CustomerStatus: ACTIVE | BANNED

-- نوع الصفحة المخصصة
PageType: LANDING | CUSTOM | POLICY

-- حالة الصفحة
PageStatus: DRAFT | PUBLISHED | ARCHIVED

-- حالة الطلب
OrderStatus: PENDING | CONFIRMED | PROCESSING | SHIPPED | DELIVERED | CANCELLED | REFUNDED

-- حالة الدفع
PaymentStatus: PENDING | PAID | FAILED | REFUNDED
```

#### Table: `User`

```sql
CREATE TABLE "User" (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email        VARCHAR NOT NULL,
  password     VARCHAR NOT NULL,              -- bcrypt hashed
  role         UserRole NOT NULL DEFAULT 'CUSTOMER',
  refreshToken VARCHAR,                       -- hashed refresh token
  storeId      UUID REFERENCES "Store"(id),  -- NULL for platform users
  createdAt    TIMESTAMP DEFAULT NOW(),
  updatedAt    TIMESTAMP,
  UNIQUE (email, storeId)                    -- same email can exist in multiple stores
);
```

> **Note:** The `(email, storeId)` unique constraint allows the same email address to be a customer in multiple stores, while platform users have `storeId = NULL`.

#### Table: `Merchant`

```sql
CREATE TABLE "Merchant" (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  userId      UUID UNIQUE REFERENCES "User"(id),
  fullName    VARCHAR NOT NULL,
  phone       VARCHAR NOT NULL,
  storeName   VARCHAR UNIQUE NOT NULL,
  storeSlug   VARCHAR UNIQUE NOT NULL,      -- URL-friendly store identifier
  category    VARCHAR NOT NULL,             -- business category
  country     VARCHAR NOT NULL,
  city        VARCHAR NOT NULL,
  description VARCHAR,
  status      MerchantStatus DEFAULT 'PENDING',
  createdAt   TIMESTAMP DEFAULT NOW(),
  updatedAt   TIMESTAMP
);
```

#### Table: `Store`

```sql
CREATE TABLE "Store" (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchantId     UUID UNIQUE REFERENCES "Merchant"(id),
  slug           VARCHAR UNIQUE NOT NULL,
  name           VARCHAR NOT NULL,
  customDomain   VARCHAR UNIQUE,            -- optional custom domain
  domainStatus   VARCHAR,
  themeId        VARCHAR,
  isOnboarded    BOOLEAN DEFAULT false,
  
  -- Branding / Appearance
  logo           VARCHAR,                   -- URL to logo image
  logoWidth      INTEGER,
  logoHeight     INTEGER,
  showStoreName  BOOLEAN DEFAULT true,
  favicon        VARCHAR,
  storeName      VARCHAR,
  textColor      VARCHAR,
  headingColor   VARCHAR,
  buttonColor    VARCHAR,
  primaryColor   VARCHAR,
  secondaryColor VARCHAR,
  accentColor    VARCHAR,
  fontFamily     VARCHAR,
  borderRadius   VARCHAR,
  
  enabledPaymentMethods  VARCHAR[] DEFAULT '{"cash_on_delivery"}',
  createdAt      TIMESTAMP DEFAULT NOW(),
  updatedAt      TIMESTAMP
);
```

#### Table: `Product`

```sql
CREATE TABLE "Product" (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  storeId      UUID REFERENCES "Store"(id),
  name         VARCHAR NOT NULL,
  description  TEXT,
  price        FLOAT NOT NULL,
  comparePrice FLOAT,                       -- original price for discounts
  cost         FLOAT,                       -- cost price
  sku          VARCHAR,
  barcode      VARCHAR,
  quantity     INTEGER DEFAULT 0,
  trackStock   BOOLEAN DEFAULT true,
  weight       FLOAT,
  isPhysical   BOOLEAN DEFAULT true,
  category     VARCHAR,
  categoryId   UUID REFERENCES "Category"(id),
  tags         VARCHAR[],
  images       VARCHAR[],                   -- array of image URLs
  slug         VARCHAR NOT NULL,
  status       ProductStatus DEFAULT 'DRAFT',
  seoTitle     VARCHAR,
  seoDesc      VARCHAR,
  createdAt    TIMESTAMP DEFAULT NOW(),
  updatedAt    TIMESTAMP,
  UNIQUE (storeId, slug)
);
```

#### Table: `ProductOption` & `ProductOptionValue`

```sql
-- خيارات المنتج (مثل: اللون، المقاس)
CREATE TABLE "ProductOption" (
  id        UUID PRIMARY KEY,
  productId UUID REFERENCES "Product"(id) ON DELETE CASCADE,
  name      VARCHAR NOT NULL,               -- e.g., "اللون", "المقاس"
  type      VARCHAR DEFAULT 'DROPDOWN',
  position  INTEGER DEFAULT 0,
  createdAt TIMESTAMP,
  updatedAt TIMESTAMP
);

-- قيم الخيار (مثل: أحمر، أزرق)
CREATE TABLE "ProductOptionValue" (
  id       UUID PRIMARY KEY,
  optionId UUID REFERENCES "ProductOption"(id) ON DELETE CASCADE,
  value    VARCHAR NOT NULL,
  position INTEGER DEFAULT 0
);
```

#### Table: `ProductVariant`

```sql
-- تركيبات المنتج (مثل: أحمر - مقاس L)
CREATE TABLE "ProductVariant" (
  id           UUID PRIMARY KEY,
  productId    UUID REFERENCES "Product"(id) ON DELETE CASCADE,
  sku          VARCHAR,
  price        FLOAT,
  comparePrice FLOAT,
  quantity     INTEGER DEFAULT 0,
  image        VARCHAR,
  isActive     BOOLEAN DEFAULT true,
  createdAt    TIMESTAMP,
  updatedAt    TIMESTAMP
);

-- ربط المتغير بقيم الخيارات
CREATE TABLE "ProductVariantValue" (
  id            UUID PRIMARY KEY,
  variantId     UUID REFERENCES "ProductVariant"(id) ON DELETE CASCADE,
  optionValueId UUID REFERENCES "ProductOptionValue"(id) ON DELETE CASCADE,
  UNIQUE (variantId, optionValueId)
);
```

#### Table: `ProductOffer`

```sql
-- عروض خاصة لكميات محددة (bundle pricing)
CREATE TABLE "ProductOffer" (
  id          UUID PRIMARY KEY,
  productId   UUID REFERENCES "Product"(id) ON DELETE CASCADE,
  title       VARCHAR NOT NULL,
  description VARCHAR,
  quantity    INTEGER NOT NULL,             -- الكمية المطلوبة للحصول على العرض
  price       DECIMAL NOT NULL,             -- سعر الكمية
  badge       VARCHAR,                      -- نص الشارة (مثل: "الأكثر مبيعاً")
  sortOrder   INTEGER DEFAULT 0,
  isActive    BOOLEAN DEFAULT true,
  createdAt   TIMESTAMP
);
```

#### Table: `Order`

```sql
CREATE TABLE "Order" (
  id              UUID PRIMARY KEY,
  orderCode       VARCHAR UNIQUE NOT NULL,  -- human-readable code (e.g., ORD-12345)
  storeId         UUID REFERENCES "Store"(id),
  
  -- Customer reference (NULL = guest order)
  customerId      UUID REFERENCES "Customer"(id),
  
  -- Snapshot at time of purchase (not references — data preserved even if customer deleted)
  customerName    VARCHAR NOT NULL,
  customerEmail   VARCHAR,
  customerPhone   VARCHAR NOT NULL,
  
  -- Shipping address snapshot
  shippingCity     VARCHAR NOT NULL,
  shippingRegion   VARCHAR NOT NULL,
  shippingStreet   VARCHAR NOT NULL,
  shippingBuilding VARCHAR,
  
  paymentMethod   VARCHAR NOT NULL,         -- e.g., "cash_on_delivery"
  paymentStatus   PaymentStatus DEFAULT 'PENDING',
  transactionId   VARCHAR,
  
  subtotal        DECIMAL NOT NULL,
  shippingCost    DECIMAL DEFAULT 0,
  total           DECIMAL NOT NULL,
  notes           VARCHAR,
  status          OrderStatus DEFAULT 'PENDING',
  
  createdAt       TIMESTAMP DEFAULT NOW(),
  updatedAt       TIMESTAMP
);
```

#### Table: `OrderItem`

```sql
CREATE TABLE "OrderItem" (
  id           UUID PRIMARY KEY,
  orderId      UUID REFERENCES "Order"(id),
  productId    UUID NOT NULL,
  productName  VARCHAR NOT NULL,            -- snapshot of product name
  productImage VARCHAR,
  price        DECIMAL NOT NULL,
  quantity     INTEGER NOT NULL,
  total        DECIMAL NOT NULL
);
```

#### Table: `Customer`

```sql
CREATE TABLE "Customer" (
  id        UUID PRIMARY KEY,
  storeId   UUID REFERENCES "Store"(id),
  userId    UUID REFERENCES "User"(id),
  fullName  VARCHAR NOT NULL,
  phone     VARCHAR,
  status    CustomerStatus DEFAULT 'ACTIVE',
  createdAt TIMESTAMP,
  updatedAt TIMESTAMP,
  UNIQUE (storeId, userId)               -- one customer profile per store
);
```

#### Table: `Category`

```sql
CREATE TABLE "Category" (
  id        UUID PRIMARY KEY,
  storeId   UUID REFERENCES "Store"(id),
  name      VARCHAR NOT NULL,
  slug      VARCHAR NOT NULL,
  image     VARCHAR,
  sortOrder INTEGER DEFAULT 0,
  createdAt TIMESTAMP,
  updatedAt TIMESTAMP,
  UNIQUE (storeId, slug)
);
```

#### Table: `Review`

```sql
CREATE TABLE "Review" (
  id         UUID PRIMARY KEY,
  storeId    UUID REFERENCES "Store"(id),
  productId  UUID REFERENCES "Product"(id) ON DELETE CASCADE,
  customerId UUID REFERENCES "Customer"(id),
  rating     INTEGER NOT NULL,              -- 1-5 stars
  comment    TEXT,
  createdAt  TIMESTAMP,
  updatedAt  TIMESTAMP,
  UNIQUE (customerId, productId)            -- one review per customer per product
);
```

#### Table: `Page`

```sql
-- الصفحات المخصصة ومنشئ الصفحات
CREATE TABLE "Page" (
  id              UUID PRIMARY KEY,
  storeId         UUID REFERENCES "Store"(id),
  title           VARCHAR NOT NULL,
  slug            VARCHAR NOT NULL,
  type            PageType NOT NULL,        -- LANDING | CUSTOM | POLICY
  status          PageStatus DEFAULT 'DRAFT',
  content         JSONB DEFAULT '{}',       -- Puck editor JSON
  showHeader      BOOLEAN DEFAULT false,
  showFooter      BOOLEAN DEFAULT false,
  linkedProductId UUID REFERENCES "Product"(id),
  seoTitle        VARCHAR,
  seoDescription  VARCHAR,
  version         INTEGER DEFAULT 1,
  createdAt       TIMESTAMP,
  updatedAt       TIMESTAMP,
  UNIQUE (storeId, slug)
);
```

#### Table: `Address`

```sql
CREATE TABLE "Address" (
  id         UUID PRIMARY KEY,
  customerId UUID REFERENCES "Customer"(id),
  fullName   VARCHAR NOT NULL,
  phone      VARCHAR NOT NULL,
  city       VARCHAR NOT NULL,
  region     VARCHAR NOT NULL,
  street     VARCHAR NOT NULL,
  buildingNo VARCHAR,
  isDefault  BOOLEAN DEFAULT false,
  createdAt  TIMESTAMP
);
```

#### Table: `Wishlist`

```sql
CREATE TABLE "Wishlist" (
  id         UUID PRIMARY KEY,
  storeId    UUID REFERENCES "Store"(id),
  customerId UUID REFERENCES "Customer"(id),
  productId  UUID REFERENCES "Product"(id) ON DELETE CASCADE,
  createdAt  TIMESTAMP,
  UNIQUE (customerId, productId)
);
```

### 3.2 Analytics Database (TimescaleDB — analytics.prisma)

The analytics database uses a **separate PostgreSQL connection** on port 5433 with TimescaleDB extension. Raw event tables are TimescaleDB **hypertables**.

#### Enums

```sql
DeviceType:           MOBILE | TABLET | DESKTOP | UNKNOWN
AnalyticsEventType:   CART_ADD | CART_REMOVE | CART_ABANDON | CHECKOUT_START | PRODUCT_VIEW | BUTTON_CLICK
HeatmapEventType:     CLICK | MOVE | SCROLL
```

#### Table: `page_views` (Hypertable — partitioned by `time`)

```sql
-- جدول مشاهدات الصفحات (hypertable TimescaleDB)
CREATE TABLE page_views (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  time      TIMESTAMPTZ DEFAULT NOW(),     -- partition key
  storeId   VARCHAR NOT NULL,
  sessionId VARCHAR NOT NULL,             -- anonymous session UUID
  pageSlug  VARCHAR NOT NULL,             -- e.g., "/products/shirt"
  referrer  VARCHAR,                      -- referrer domain only (no full URL)
  device    DeviceType DEFAULT 'UNKNOWN',
  browser   VARCHAR,
  country   VARCHAR,                      -- derived from IP at request time; IP discarded
  city      VARCHAR,
  duration  INTEGER,                      -- seconds

  INDEX (storeId, time),
  INDEX (storeId, pageSlug, time)
);
-- Partition: 1-day chunks
-- Retention: 90 days
```

#### Table: `analytics_events` (Hypertable)

```sql
-- جدول أحداث التتبع (hypertable TimescaleDB)
CREATE TABLE analytics_events (
  id        UUID PRIMARY KEY,
  time      TIMESTAMPTZ DEFAULT NOW(),
  storeId   VARCHAR NOT NULL,
  sessionId VARCHAR NOT NULL,
  type      AnalyticsEventType NOT NULL,
  pageSlug  VARCHAR NOT NULL,
  metadata  JSONB,                        -- additional event data

  INDEX (storeId, time),
  INDEX (storeId, type, time)
);
```

#### Table: `heatmap_data` (Hypertable)

```sql
-- بيانات خريطة الحرارة (hypertable TimescaleDB)
CREATE TABLE heatmap_data (
  id       UUID PRIMARY KEY,
  time     TIMESTAMPTZ DEFAULT NOW(),
  storeId  VARCHAR NOT NULL,
  pageSlug VARCHAR NOT NULL,
  x        FLOAT NOT NULL,              -- percentage from left (0-100)
  y        FLOAT NOT NULL,              -- percentage from top (0-100)
  type     HeatmapEventType NOT NULL,
  device   DeviceType DEFAULT 'DESKTOP',

  INDEX (storeId, pageSlug, type, device),
  INDEX (storeId, time)
);
```

#### Table: `analytics_hourly` (Regular PostgreSQL)

```sql
-- إحصائيات مجمعة كل ساعة
CREATE TABLE analytics_hourly (
  id             UUID PRIMARY KEY,
  storeId        VARCHAR NOT NULL,
  hour           TIMESTAMPTZ NOT NULL,    -- start of hour (UTC)
  pageViews      INTEGER DEFAULT 0,
  uniqueVisitors INTEGER DEFAULT 0,
  avgDuration    FLOAT DEFAULT 0,
  bounceRate     FLOAT DEFAULT 0,
  mobileCount    INTEGER DEFAULT 0,
  tabletCount    INTEGER DEFAULT 0,
  desktopCount   INTEGER DEFAULT 0,
  cartAdds       INTEGER DEFAULT 0,
  cartAbandons   INTEGER DEFAULT 0,
  checkoutStarts INTEGER DEFAULT 0,

  UNIQUE (storeId, hour),
  INDEX (storeId, hour)
);
```

#### Table: `analytics_daily` (Regular PostgreSQL)

```sql
-- إحصائيات مجمعة يومياً
CREATE TABLE analytics_daily (
  id             UUID PRIMARY KEY,
  storeId        VARCHAR NOT NULL,
  date           TIMESTAMPTZ NOT NULL,    -- start of day (UTC midnight)
  pageViews      INTEGER DEFAULT 0,
  uniqueVisitors INTEGER DEFAULT 0,
  avgDuration    FLOAT DEFAULT 0,
  bounceRate     FLOAT DEFAULT 0,
  mobileCount    INTEGER DEFAULT 0,
  tabletCount    INTEGER DEFAULT 0,
  desktopCount   INTEGER DEFAULT 0,
  cartAdds       INTEGER DEFAULT 0,
  cartAbandons   INTEGER DEFAULT 0,
  checkoutStarts INTEGER DEFAULT 0,
  organicCount   INTEGER DEFAULT 0,      -- Google, Bing, etc.
  socialCount    INTEGER DEFAULT 0,       -- Facebook, Instagram, etc.
  directCount    INTEGER DEFAULT 0,       -- no referrer
  referralCount  INTEGER DEFAULT 0,       -- other referrers
  topPages       JSONB DEFAULT '[]',      -- [{slug, views}]
  countries      JSONB DEFAULT '[]',      -- [{country, count}]

  UNIQUE (storeId, date),
  INDEX (storeId, date)
);
```

### Entity Relationship Diagram

```mermaid
erDiagram
    User ||--o| Merchant : "has"
    User ||--o{ Customer : "is"
    Merchant ||--o| Store : "owns"
    Store ||--o{ Product : "has"
    Store ||--o{ Order : "receives"
    Store ||--o{ Customer : "has"
    Store ||--o{ Category : "has"
    Store ||--o{ Page : "has"
    Product ||--o{ OrderItem : "in"
    Product ||--o{ Review : "has"
    Product ||--o{ ProductOption : "has"
    Product ||--o{ ProductVariant : "has"
    Product ||--o{ ProductOffer : "has"
    Product ||--o{ Wishlist : "in"
    ProductOption ||--o{ ProductOptionValue : "has"
    ProductVariant ||--o{ ProductVariantValue : "has"
    ProductOptionValue ||--o{ ProductVariantValue : "linked"
    Order ||--o{ OrderItem : "contains"
    Customer ||--o{ Order : "places"
    Customer ||--o{ Address : "has"
    Customer ||--o{ PaymentMethod : "has"
    Customer ||--o{ Review : "writes"
    Customer ||--o{ Wishlist : "has"
```

---

## 4. API Endpoints Reference

> **Base URL:** `http://localhost:8000/api`  
> **Auth:** Cookie-based JWT (`access_token` header via HTTP-only cookie)

### 4.1 Authentication — `/api/auth`

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/auth/platform/login` | Public | تسجيل دخول التاجر/المشرف |
| POST | `/auth/platform/register` | Public | تسجيل تاجر جديد |
| POST | `/auth/customer/login` | Public | تسجيل دخول العميل |
| POST | `/auth/customer/register` | Public | تسجيل عميل جديد |
| POST | `/auth/refresh` | JwtRefreshGuard | تجديد التوكن |
| POST | `/auth/logout` | JwtAuthGuard | تسجيل الخروج |
| POST | `/auth/customer/logout` | Customer cookie | تسجيل خروج العميل |
| POST | `/auth/customer/refresh` | Customer cookie | تجديد توكن العميل |
| GET | `/auth/me` | JwtAuthGuard | جلب بيانات المستخدم |

**POST `/auth/platform/login`**
```typescript
// Request Body
{
  email: string     // البريد الإلكتروني
  password: string  // كلمة المرور
}

// Response 200
{
  user: {
    id: string
    email: string
    role: 'MERCHANT' | 'SUPERADMIN'
    merchant?: {
      status: 'PENDING' | 'ACTIVE' | 'REJECTED'
      storeName: string
      storeSlug: string
    }
  }
}
// Sets cookies: access_token, refresh_token
```

**POST `/auth/platform/register`**
```typescript
// Request Body
{
  email: string
  password: string
  fullName: string
  phone: string
  storeName: string   // unique store name
  category: string    // business category
  country: string
  city: string
  description?: string
}

// Response 201
{
  message: 'Application submitted successfully'
  user: { id, email, role, merchant: { status: 'PENDING', ... } }
}
```

**GET `/auth/me`**
```typescript
// Response 200
{
  id: string
  email: string
  role: 'MERCHANT' | 'SUPERADMIN' | 'CUSTOMER'
  merchant?: { status, storeName, storeSlug }
  customer?: { fullName, phone, addresses[] }
}
```

---

### 4.2 Merchant — `/api/merchant` (MerchantGuard required)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/merchant/me` | Store + merchant info |
| PATCH | `/merchant/store/customization` | Update store branding |
| POST | `/merchant/store/upload-image` | Upload logo/favicon (multipart) |
| GET | `/merchant/store/payment-methods` | Get enabled payment gateways |
| PATCH | `/merchant/store/payment-methods` | Update enabled gateways |
| GET | `/merchant/orders` | List orders (paginated) |
| GET | `/merchant/orders/:orderCode` | Order detail |
| PATCH | `/merchant/orders/:orderCode/status` | Update order status |
| GET | `/merchant/customers` | List customers |
| PATCH | `/merchant/customers/:id/status` | ACTIVE/BANNED toggle |

**GET `/merchant/orders`**
```typescript
// Query Params
{
  status?: OrderStatus     // filter by status
  page?: number            // default: 1
  limit?: number           // default: 20
  search?: string          // search by orderCode or customer name
}

// Response 200
{
  data: Order[]
  total: number
  page: number
  limit: number
}
```

**PATCH `/merchant/store/customization`**
```typescript
// Request Body (all optional)
{
  logo?: string
  favicon?: string
  primaryColor?: string
  secondaryColor?: string
  accentColor?: string
  textColor?: string
  headingColor?: string
  buttonColor?: string
  fontFamily?: string
  borderRadius?: string
  showStoreName?: boolean
}
```

---

### 4.3 Products — `/api/merchant/products` (MerchantGuard required)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/merchant/products` | List products |
| GET | `/merchant/products/:id` | Get product by ID |
| POST | `/merchant/products` | Create product |
| PATCH | `/merchant/products/:id` | Update product |
| DELETE | `/merchant/products/:id` | Delete product |
| GET | `/merchant/products/:id/offers` | List product offers |
| POST | `/merchant/products/:id/offers` | Create offer |
| PATCH | `/merchant/products/:id/offers/:offerId` | Update offer |
| DELETE | `/merchant/products/:id/offers/:offerId` | Delete offer |

**POST `/merchant/products`**
```typescript
// Request Body
{
  name: string
  description?: string
  price: number
  comparePrice?: number
  cost?: number
  sku?: string
  barcode?: string
  quantity?: number            // default: 0
  trackStock?: boolean         // default: true
  weight?: number
  isPhysical?: boolean         // default: true
  categoryId?: string
  tags?: string[]
  images?: string[]            // array of image URLs
  slug: string
  status?: 'DRAFT' | 'ACTIVE' | 'ARCHIVED'
  seoTitle?: string
  seoDesc?: string
  options?: Array<{
    name: string
    type?: string              // default: "DROPDOWN"
    values: string[]
  }>
}
```

---

### 4.4 Categories — `/api/merchant/categories` (MerchantGuard required)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/merchant/categories` | List categories |
| POST | `/merchant/categories` | Create category |
| PATCH | `/merchant/categories/:id` | Update category |
| DELETE | `/merchant/categories/:id` | Delete category |

---

### 4.5 Orders — `/api/orders` (Public + Throttled)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/orders` | Optional (customer cookie) | Create order |
| GET | `/orders/:orderCode` | Public | Get order by code |

**POST `/orders`**
```typescript
// Request Body
{
  storeSlug: string
  items: Array<{
    productId: string
    quantity: number
    variantId?: string
  }>
  customerName: string
  customerEmail?: string
  customerPhone: string
  shippingCity: string
  shippingRegion: string
  shippingStreet: string
  shippingBuilding?: string
  paymentMethod: string        // e.g., "cash_on_delivery"
  notes?: string
}

// Response 201
{
  orderCode: string
  orderId: string
  status: OrderStatus
  paymentMethod: string
  customerName: string
  total: number
  subtotal: number
  shippingCost: number
  createdAt: Date
  estimatedDelivery: string    // e.g., "3-5 أيام عمل"
  items: OrderItem[]
  shippingAddress: { city, region, street, building }
}
```

---

### 4.6 Stores — `/api/stores` (Public)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/stores/:slug` | Get store by slug (full data) |
| GET | `/stores/:storeId/products/:productIdOrSlug` | Get product |
| GET | `/stores/:slug/pages/:pageSlug` | Get published page |

---

### 4.7 Customer — `/api/customer` (Customer Guard required)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/customer/profile` | Customer profile |
| PATCH | `/customer/profile` | Update profile |
| GET | `/customer/addresses` | List addresses |
| POST | `/customer/addresses` | Add address |
| PATCH | `/customer/addresses/:id` | Update address |
| DELETE | `/customer/addresses/:id` | Delete address |
| GET | `/customer/orders` | Customer's orders |

---

### 4.8 Reviews — `/api/reviews`

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/reviews/:productId` | Public | Get product reviews |
| POST | `/reviews` | Customer Guard | Submit review |

---

### 4.9 Pages — `/api/pages` (Merchant Guard)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/pages` | List merchant pages |
| POST | `/pages` | Create page |
| GET | `/pages/:id` | Get page |
| PATCH | `/pages/:id` | Update page content |
| PATCH | `/pages/:id/status` | Publish/archive page |
| DELETE | `/pages/:id` | Delete page |

---

### 4.10 Analytics — `/api/analytics` & `/api/merchant/analytics`

#### Collection Endpoint (Public)

| Method | Endpoint | Auth | Rate Limit |
|--------|----------|------|------------|
| POST | `/analytics/collect` | Public | 100 req/min per sessionId |

**POST `/analytics/collect`**
```typescript
// Request Body (max 2KB)
{
  storeRef: string     // storeId UUID or slug
  sessionId: string    // anonymous 32-char hex UUID
  type: 'pageview' | 'click' | 'move' | 'scroll'
  page: string         // pathname, e.g., "/products/shirt"
  referrer?: string    // referrer domain only
  device?: string      // mobile | tablet | desktop
  browser?: string     // chrome | safari | firefox | edge | opera
  x?: number           // click/move: x percentage (0-100)
  y?: number           // click/move: y percentage (0-100)
  depth?: number       // scroll: max depth percentage
  ts: number           // client timestamp (Unix ms)
}

// Response 200 (< 50ms — fire and forget)
{ ok: true }
```

#### Merchant Analytics Endpoints (MerchantGuard required)

| Method | Endpoint | Default | Description |
|--------|----------|---------|-------------|
| GET | `/merchant/analytics/overview` | period=7d | KPI summary |
| GET | `/merchant/analytics/traffic` | period=7d | Traffic breakdown |
| GET | `/merchant/analytics/pages` | period=7d | Page performance |
| GET | `/merchant/analytics/funnel` | period=7d | Conversion funnel |
| GET | `/merchant/analytics/sales` | period=30d | Sales analytics |
| GET | `/merchant/analytics/heatmap` | page=/ type=CLICK | Heatmap data |

**GET `/merchant/analytics/overview`**
```typescript
// Query: ?period=7d   (1d | 7d | 30d | 90d | 1y | all)

// Response 200
{
  totalVisitors: number
  totalPageViews: number
  avgDuration: number          // seconds
  bounceRate: number           // percentage (0-100)
  cartAdds: number
  cartAbandons: number
  checkoutStarts: number
  totalOrders: number
  totalRevenue: number         // SAR
  avgOrderValue: number        // SAR
  conversionRate: number       // percentage (0-100)
  trend: {
    visitors: number           // % change vs previous period
    revenue: number
    orders: number
  }
}
```

**GET `/merchant/analytics/traffic`**
```typescript
// Response 200
{
  daily: Array<{ date: string, visitors: number, pageViews: number }>
  devices: { mobile: number, tablet: number, desktop: number }
  sources: { organic: number, social: number, direct: number, referral: number }
  countries: Array<{ country: string, count: number }>  // top 10
}
```

**GET `/merchant/analytics/funnel`**
```typescript
// Response 200 — steps with Arabic labels
{
  steps: [
    { name: 'زوار', count: number },
    { name: 'مشاهدة منتج', count: number },
    { name: 'إضافة للسلة', count: number },
    { name: 'بدء الدفع', count: number },
    { name: 'شراء', count: number },
  ]
}
```

**GET `/merchant/analytics/heatmap`**
```typescript
// Query: ?page=/products&type=CLICK&device=DESKTOP
// type: CLICK | MOVE | SCROLL
// device: MOBILE | DESKTOP

// Response 200
{
  points: Array<{ x: number, y: number }>  // percentages (0-100)
  count: number
  hasData: boolean
}
```

---

### 4.11 Superadmin — `/api/superadmin` (SuperadminGuard required)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/superadmin/merchants` | List all merchants |
| GET | `/superadmin/merchants/:id` | Get merchant detail |
| PATCH | `/superadmin/merchants/:id/approve` | Approve merchant + create store |
| PATCH | `/superadmin/merchants/:id/reject` | Reject merchant |

**PATCH `/superadmin/merchants/:id/approve`**
```typescript
// Response 200
{
  message: 'Merchant approved successfully'
  merchant: { id, status: 'ACTIVE', ... }
  store: { id, slug, name, ... }     // newly created store
}
```

---

## 5. Authentication & Authorization

### JWT Strategy

```typescript
// Two separate secrets for access and refresh tokens
JWT_ACCESS_SECRET  →  short-lived (15 minutes)
JWT_REFRESH_SECRET →  long-lived (7 days)

// Token payload
{
  sub: string        // User UUID
  email: string
  role: UserRole
  storeId?: string   // for customer tokens (null for platform users)
  iat: number
  exp: number
}
```

### Cookie Configuration

Cookies are set in the auth service:

```typescript
// Platform cookies (merchant + superadmin)
res.cookie('access_token',  accessToken,  { httpOnly: true, sameSite: 'lax', ... })
res.cookie('refresh_token', refreshToken, { httpOnly: true, sameSite: 'lax', ... })

// Customer cookies (per-store)
res.cookie('customer_access_token',  ..., { httpOnly: true, sameSite: 'lax', ... })
res.cookie('customer_refresh_token', ..., { httpOnly: true, sameSite: 'lax', ... })
```

### Guards Chain

```
Request
  │
  ├── ThrottlerGuard     — rate limiting (global or per-route)
  │
  ├── MerchantGuard      — extends JwtAuthGuard; requires MERCHANT or SUPERADMIN role
  │   └── JwtAuthGuard   — validates access_token cookie
  │       └── JwtAccessStrategy — extracts user from JWT
  │
  ├── SuperadminGuard    — requires SUPERADMIN role specifically
  │
  ├── CustomerGuard      — validates customer_access_token cookie
  │
  └── JwtRefreshGuard    — validates refresh_token cookie (refresh endpoint only)
```

### Role Hierarchy

```
SUPERADMIN > MERCHANT > CUSTOMER
```

| Guard | Allowed Roles |
|-------|---------------|
| `JwtAuthGuard` | Any authenticated user |
| `MerchantGuard` | MERCHANT + SUPERADMIN |
| `SuperadminGuard` | SUPERADMIN only |
| `CustomerGuard` | CUSTOMER (storefront) |

### Refresh Token Security

Refresh tokens are **hashed with bcrypt** before storage:

```typescript
// Store hashed refresh token in DB
await prisma.user.update({
  where: { id: userId },
  data: { refreshToken: await bcrypt.hash(refreshToken, 10) },
})

// Validate on refresh request
const isValid = await bcrypt.compare(incomingToken, storedHashedToken)
```

---

## 6. Business Logic

### 6.1 Merchant Approval Workflow

```mermaid
sequenceDiagram
    participant M as Merchant
    participant A as Auth API
    participant S as Superadmin API
    participant DB as Database

    M->>A: POST /auth/platform/register
    A->>DB: Create User (MERCHANT role, PENDING status)
    A-->>M: "Application submitted" + access token

    M->>M: Sees /pending page (status check on login)

    S->>S: GET /superadmin/merchants?status=PENDING
    S->>S: Reviews merchant application

    S->>S: PATCH /superadmin/merchants/:id/approve
    S->>DB: UPDATE Merchant status = ACTIVE
    S->>DB: CREATE Store (from merchant data)
    S-->>S: Returns { merchant, store }

    M->>A: Next login → status = ACTIVE
    M->>M: Full dashboard access
```

When a merchant is **approved**, the `approveMerchant` method in `superadmin.service.ts` automatically creates the `Store` record with the merchant's `storeSlug` as the store slug.

### 6.2 Order Processing

```typescript
// Order creation flow
async createOrder(dto: CreateOrderDto, userId?: string) {
  // 1. Validate store exists by slug
  // 2. Resolve product IDs and calculate prices
  // 3. Check stock availability (if trackStock = true)
  // 4. Generate unique order code (e.g., ORD-12345)
  // 5. Create Order + OrderItems in a transaction
  // 6. Decrement product quantity if trackStock
  // 7. Link to customer if userId provided
  // 8. Return order summary
}
```

**Order Code Format:** Generated by `order-code.util.ts` — format: `ORD-XXXXX` (5 random alphanumeric characters).

**Order Lifecycle:**
```
PENDING → CONFIRMED → PROCESSING → SHIPPED → DELIVERED
         ↘ CANCELLED
         ↘ REFUNDED
```

### 6.3 Payment Gateway Pattern

The payment system uses a **registry pattern** for extensibility:

```typescript
// Payment registry — gateways are registered by key
registry.register('cash_on_delivery', new CashOnDeliveryGateway())

// Each gateway implements BaseGateway
abstract class BaseGateway {
  abstract key: string
  abstract label: string
  abstract process(order: Order): Promise<PaymentResult>
}
```

Currently only **Cash on Delivery** is implemented. The architecture supports adding Stripe, PayTabs, etc.

### 6.4 File Upload

Store images (logo, favicon) are uploaded via multipart form to:
- **Storage:** `uploads/stores/:merchantId/` (local disk)
- **Served at:** `GET /:merchantId/:filename` (static assets)
- **URL format:** `http://SERVER_URL/uploads/stores/:merchantId/:timestamp-filename`
- **Allowed types:** jpg, jpeg, png, svg, ico, webp
- **Max size:** 2MB

---

## 7. Analytics System

### 7.1 Collection Pipeline

```mermaid
sequenceDiagram
    participant T as Tracker Script
    participant C as /api/analytics/collect
    participant B as In-Memory Buffer
    participant G as GeoService
    participant D as Analytics DB

    T->>C: sendBeacon (pageview/click/scroll/move)
    C->>C: Validate storeRef → resolve storeId
    C->>G: lookup(ip) → { country }
    Note over G: IP is immediately discarded
    C->>B: push({ ...event, storeId, country })
    C-->>T: 200 OK (< 50ms)

    loop Every 10 seconds
        B->>D: batch INSERT page_views / analytics_events / heatmap_data
    end
```

### 7.2 Event Processing

Events are processed by `analytics.service.ts → processBatch()`:

| Event Type | Target Table |
|-----------|--------------|
| `pageview` | `page_views` |
| `click` | `heatmap_data` (type=CLICK) |
| `move` | `heatmap_data` (type=MOVE) |
| `scroll` | `heatmap_data` (type=SCROLL) |
| `product_view` | `analytics_events` |
| `cart_add` | `analytics_events` |
| `cart_abandon` | `analytics_events` |
| `checkout_start` | `analytics_events` |

### 7.3 Geo Resolution

`geo.service.ts` uses the `geoip-country` npm package for IP-to-country lookup:

```typescript
// IP is resolved once, then discarded — never stored
const { country } = this.geoService.lookup(ip)
// country = "SA" (ISO 3166-1 alpha-2)
```

### 7.4 Multi-Store Isolation

```typescript
// storeRef can be UUID or slug — resolved to storeId
async resolveStore(storeRef: string): Promise<string | null> {
  const store = await this.prisma.store.findFirst({
    where: {
      OR: [{ id: storeRef }, { slug: storeRef }]
    }
  })
  return store?.id ?? null
}

// All analytics records contain storeId
// Merchants can ONLY query their own storeId (enforced in merchant-analytics.controller.ts)
```

---

## 8. Background Jobs

### 8.1 Aggregation Service (Cron)

`aggregation.service.ts` runs two scheduled jobs:

#### Hourly Aggregation

```typescript
@Cron('0 * * * *')  // runs at minute 0 of every hour
async aggregateHourly() {
  // كل متجر يُعالج بشكل منفصل مع تأخير 100ms
  for (const store of allStores) {
    await this.computeHour(store.id, previousHour)
    await delay(100)  // منع إجهاد قاعدة البيانات
  }
}
```

**computeHour()** aggregates:
- Page views count
- Unique session count
- Device breakdown (mobile/tablet/desktop)
- Cart adds, abandons, checkout starts

#### Daily Aggregation

```typescript
@Cron('0 0 * * *')  // runs at midnight UTC
async aggregateDaily() {
  for (const store of allStores) {
    await this.computeDay(store.id, yesterday)
    await delay(100)
  }
}
```

**computeDay()** aggregates (from raw `page_views` table):
- Unique sessions (unique visitors)
- Traffic source classification:
  - **Organic:** referrer matches Google/Bing/Yahoo/DuckDuckGo
  - **Social:** referrer matches Facebook/Instagram/Twitter/TikTok
  - **Direct:** no referrer
  - **Referral:** all other referrers
- Country visitor counts (top 10 stored as JSON)
- Average session duration

#### Idempotency

All aggregation uses **upsert** (insert or update) to ensure running twice produces the same result:

```typescript
await analyticsPrisma.analyticsHourly.upsert({
  where: { storeId_hour: { storeId, hour } },
  create: { ...computedData },
  update: { ...computedData },  // same data — idempotent
})
```

### 8.2 Buffer Flush Timer

The analytics controller flushes its in-memory buffer every **10 seconds**:

```typescript
// Initialized in AnalyticsController constructor
this.flushTimer = setInterval(() => this.flush(), 10000)

// Also flushes on module destroy (graceful shutdown)
onModuleDestroy() {
  clearInterval(this.flushTimer)
  this.flush()  // Final flush before shutdown
}
```

---

## 9. Configuration

### Environment Variables

```bash
# .env (server)

# Main Database
DATABASE_URL="postgresql://user:password@localhost:5432/tarmeez"

# Analytics Database (TimescaleDB)
ANALYTICS_DATABASE_URL="postgresql://user:password@localhost:5433/tarmeez_analytics"

# JWT Secrets (use long random strings in production)
JWT_ACCESS_SECRET="your-super-secret-access-key"
JWT_REFRESH_SECRET="your-super-secret-refresh-key"

# CORS
CLIENT_URL="http://localhost:3000"

# Server
PORT=8000
SERVER_URL="http://localhost:8000"

# Environment
NODE_ENV="development"
```

### CORS Configuration

```typescript
app.enableCors({
  origin: configService.get<string>('CLIENT_URL'),  // only allow frontend domain
  credentials: true,  // required for cookie-based auth
})
```

### Global Validation Pipe

```typescript
app.useGlobalPipes(new ValidationPipe({
  whitelist: true,            // strip unknown properties
  forbidNonWhitelisted: true, // throw on unknown properties
  transform: true,            // auto-transform types
}))
```

### Rate Limiting

```typescript
// Global ThrottlerModule configuration
ThrottlerModule.forRoot({ ttl: 60, limit: 5 })

// Analytics collect endpoint — custom rate limit
@Throttle(100, 60)  // 100 requests per 60 seconds
```

### Static Assets

Uploaded files are served as static assets:

```typescript
app.useStaticAssets(join(__dirname, '..', 'uploads'))
// Accessible at: GET /uploads/stores/:merchantId/:filename
```

---

## 10. Dependencies

### Core Framework

| Package | Version | Purpose |
|---------|---------|---------|
| `@nestjs/common` | ^11.0.1 | Decorators, guards, pipes |
| `@nestjs/core` | ^11.0.1 | NestJS application core |
| `@nestjs/platform-express` | ^11.1.16 | Express HTTP adapter |
| `@nestjs/config` | ^4.0.3 | Environment variable management |

### Database

| Package | Version | Purpose |
|---------|---------|---------|
| `@prisma/client` | ^5.22.0 | Type-safe DB client |
| `prisma` | ^5.22.0 | ORM + migration tool |

> **Note:** Analytics DB uses a separate `@prisma/analytics-client` generated to `node_modules/@prisma/analytics-client`

### Authentication

| Package | Version | Purpose |
|---------|---------|---------|
| `@nestjs/jwt` | ^11.0.2 | JWT generation and validation |
| `@nestjs/passport` | ^11.0.5 | Auth strategy integration |
| `passport` | ^0.7.0 | Core auth middleware |
| `passport-jwt` | ^4.0.1 | JWT passport strategy |
| `bcryptjs` | ^3.0.3 | Password hashing |
| `cookie-parser` | ^1.4.7 | Cookie parsing middleware |

### Background Jobs

| Package | Version | Purpose |
|---------|---------|---------|
| `@nestjs/schedule` | ^6.1.1 | Cron job support (`@Cron` decorator) |
| `@nestjs/throttler` | ^4.0.0 | Rate limiting |

### Analytics

| Package | Version | Purpose |
|---------|---------|---------|
| `geoip-country` | ^5.0.x | IP address → country lookup |

### File Upload

| Package | Version | Purpose |
|---------|---------|---------|
| `multer` | ^2.1.1 | Multipart file upload handling |

### Utilities

| Package | Version | Purpose |
|---------|---------|---------|
| `class-validator` | ^0.15.1 | DTO validation decorators |
| `class-transformer` | ^0.5.1 | DTO transformation |
| `axios` | ^1.13.6 | HTTP client (for external calls) |
| `rxjs` | ^7.8.1 | Reactive extensions (NestJS core) |

---

## 11. Data Flow

### Request → Response Flow

```
HTTP Request
     │
     ▼
[cookie-parser] → parses cookies from request
     │
     ▼
[CORS middleware] → validates Origin header
     │
     ▼
[ThrottlerGuard] → rate limit check (optional)
     │
     ▼
[Route Guard] ──┬── JwtAuthGuard → validates access_token cookie
                ├── MerchantGuard → role check
                ├── SuperadminGuard → role check
                └── CustomerGuard → validates customer_access_token
     │
     ▼
[ValidationPipe] → validates + transforms DTO
     │
     ▼
[Controller] → extract params, query, body
     │
     ▼
[Service] → business logic
     │
     ├── [PrismaService] → main database queries
     └── [AnalyticsPrismaService] → analytics database queries
     │
     ▼
[Response] → JSON serialization → HTTP response
```

### Analytics Data Flow

```
StoreFront Page Load
      │
      ▼
tarmeez-tracker.js
      │ (sendBeacon)
      ▼
POST /api/analytics/collect
      │
      ├── Validate storeRef
      ├── Lookup country from IP (IP discarded)
      └── Push to in-memory buffer
      │
      ▼ (every 10 seconds)
Batch flush to TimescaleDB
      │
      ├── page_views (pageview events)
      ├── analytics_events (cart/product events)
      └── heatmap_data (click/move/scroll)
      │
      ▼ (@Cron every hour)
AggregationService.aggregateHourly()
      → analytics_hourly (upsert)
      │
      ▼ (@Cron every midnight)
AggregationService.aggregateDaily()
      → analytics_daily (upsert)
      │
      ▼ (RTK Query polling every 60s)
GET /merchant/analytics/*
      │
AnalyticsQueryService
      ├── reads analytics_daily (aggregated)
      ├── reads page_views (raw — only for /pages endpoint)
      └── reads Order model (for sales/revenue data)
      │
      ▼
Dashboard charts + KPIs
```

---

## 12. Error Handling

### HTTP Error Codes

| Code | Scenario |
|------|---------|
| 400 | Validation error (DTO fails) |
| 401 | Unauthenticated (missing/invalid token) |
| 403 | Unauthorized (wrong role / REJECTED merchant) |
| 404 | Resource not found |
| 409 | Conflict (duplicate email, store name) |
| 429 | Rate limit exceeded |
| 500 | Internal server error |

### Validation Error Format

```typescript
// 400 Bad Request response
{
  statusCode: 400,
  message: [
    {
      property: "email",
      constraints: { isEmail: "email must be an email" }
    }
  ],
  error: "Bad Request"
}
```

### Analytics Error Handling

Analytics errors are handled silently to never impact user experience:

```typescript
// Buffer flush — logs error but never crashes
private async flush() {
  try {
    await this.analyticsService.processBatch(batch)
  } catch (err) {
    console.error('Analytics flush error:', err)  // logs only, no throw
  }
}

// Aggregation cron — per-store error isolation
for (const store of stores) {
  try {
    await this.computeHour(store.id, hour)
  } catch (err) {
    console.error(`Agg failed for ${store.id}:`, err)
    // continues to next store
  }
}
```
