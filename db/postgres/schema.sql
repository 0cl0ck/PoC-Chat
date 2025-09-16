-- Schema definition for Your Car Your Way transactional database
-- PostgreSQL DDL generated from Mermaid ER diagram

BEGIN;

-- Enum types
CREATE TYPE user_account_status AS ENUM ('ACTIVE', 'SUSPENDED', 'DELETED');
CREATE TYPE reservation_status AS ENUM ('PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED');
CREATE TYPE payment_status AS ENUM ('PENDING', 'AUTHORIZED', 'CAPTURED', 'FAILED', 'REFUNDED');
CREATE TYPE notification_status AS ENUM ('PENDING', 'SENT', 'FAILED', 'CANCELLED');

-- Users & identity
CREATE TABLE app_user (
    id               UUID PRIMARY KEY,
    email            VARCHAR(255) NOT NULL UNIQUE,
    password_hash    VARCHAR(255) NOT NULL,
    status           user_account_status NOT NULL DEFAULT 'ACTIVE',
    email_verified   BOOLEAN NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_profile (
    user_id           UUID PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
    first_name        VARCHAR(100) NOT NULL,
    last_name         VARCHAR(100) NOT NULL,
    birth_date        DATE,
    phone             VARCHAR(30),
    marketing_opt_in  BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_address (
    id             UUID PRIMARY KEY,
    user_id        UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    address_type   VARCHAR(30) NOT NULL,
    line1          VARCHAR(255) NOT NULL,
    line2          VARCHAR(255),
    city           VARCHAR(120) NOT NULL,
    postal_code    VARCHAR(20) NOT NULL,
    country_iso    CHAR(2) NOT NULL,
    timezone       VARCHAR(60) NOT NULL,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_address UNIQUE (user_id, address_type)
);

CREATE TABLE customer_payment_method (
    id                  UUID PRIMARY KEY,
    user_id             UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    psp_token           VARCHAR(255) NOT NULL,
    brand               VARCHAR(50) NOT NULL,
    last4               CHAR(4) NOT NULL,
    exp_month           SMALLINT NOT NULL CHECK (exp_month BETWEEN 1 AND 12),
    exp_year            SMALLINT NOT NULL CHECK (exp_year >= EXTRACT(YEAR FROM CURRENT_DATE)),
    billing_address_id  UUID REFERENCES user_address(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at          TIMESTAMPTZ,
    CONSTRAINT uq_payment_method UNIQUE (user_id, psp_token)
);

-- Agencies & catalog
CREATE TABLE rental_agency (
    id              UUID PRIMARY KEY,
    name            VARCHAR(150) NOT NULL,
    phone_support   VARCHAR(30),
    email_support   VARCHAR(150),
    timezone        VARCHAR(60) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE agency_location (
    id            UUID PRIMARY KEY,
    agency_id     UUID NOT NULL UNIQUE REFERENCES rental_agency(id) ON DELETE CASCADE,
    line1         VARCHAR(255) NOT NULL,
    line2         VARCHAR(255),
    city          VARCHAR(120) NOT NULL,
    postal_code   VARCHAR(20) NOT NULL,
    country_iso   CHAR(2) NOT NULL,
    latitude      NUMERIC(10,6),
    longitude     NUMERIC(10,6)
);

CREATE TABLE agency_schedule (
    id              UUID PRIMARY KEY,
    agency_id       UUID NOT NULL REFERENCES rental_agency(id) ON DELETE CASCADE,
    weekday         SMALLINT NOT NULL CHECK (weekday BETWEEN 0 AND 6),
    opens_at        TIME,
    closes_at       TIME,
    closed_all_day  BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_agency_schedule UNIQUE (agency_id, weekday)
);

CREATE TABLE vehicle_category (
    code_acriss  VARCHAR(4) PRIMARY KEY,
    segment      VARCHAR(100) NOT NULL,
    label_en     VARCHAR(150) NOT NULL,
    label_fr     VARCHAR(150) NOT NULL
);

CREATE TABLE rental_offer (
    id                 UUID PRIMARY KEY,
    agency_pickup_id   UUID NOT NULL REFERENCES rental_agency(id) ON DELETE RESTRICT,
    agency_dropoff_id  UUID NOT NULL REFERENCES rental_agency(id) ON DELETE RESTRICT,
    code_acriss        VARCHAR(4) NOT NULL REFERENCES vehicle_category(code_acriss) ON DELETE RESTRICT,
    pickup_at          TIMESTAMPTZ NOT NULL,
    dropoff_at         TIMESTAMPTZ NOT NULL,
    base_price_amount  NUMERIC(10,2) NOT NULL,
    currency           CHAR(3) NOT NULL,
    stock_total        INTEGER NOT NULL CHECK (stock_total >= 0),
    last_sync_at       TIMESTAMPTZ,
    CONSTRAINT uq_offer UNIQUE (agency_pickup_id, agency_dropoff_id, code_acriss, pickup_at, dropoff_at)
);

CREATE INDEX idx_rental_offer_pickup ON rental_offer (pickup_at);
CREATE INDEX idx_rental_offer_dropoff ON rental_offer (dropoff_at);

-- Reservations & drivers
CREATE TABLE reservation (
    id                     UUID PRIMARY KEY,
    user_id                UUID NOT NULL REFERENCES app_user(id) ON DELETE RESTRICT,
    offer_id               UUID NOT NULL REFERENCES rental_offer(id) ON DELETE RESTRICT,
    pickup_at              TIMESTAMPTZ NOT NULL,
    dropoff_at             TIMESTAMPTZ NOT NULL,
    status                 reservation_status NOT NULL,
    total_amount           NUMERIC(10,2) NOT NULL,
    currency               CHAR(3) NOT NULL,
    terms_accepted         BOOLEAN NOT NULL DEFAULT FALSE,
    cancellation_fee_pct   NUMERIC(5,2) NOT NULL DEFAULT 0,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_reservation_period CHECK (dropoff_at > pickup_at)
);

CREATE INDEX idx_reservation_user ON reservation (user_id);
CREATE INDEX idx_reservation_status ON reservation (status);
CREATE INDEX idx_reservation_pickup ON reservation (pickup_at);

CREATE TABLE reservation_driver (
    reservation_id   UUID PRIMARY KEY REFERENCES reservation(id) ON DELETE CASCADE,
    first_name       VARCHAR(100) NOT NULL,
    last_name        VARCHAR(100) NOT NULL,
    birth_date       DATE NOT NULL,
    license_country  CHAR(2) NOT NULL,
    license_number   VARCHAR(50) NOT NULL
);

CREATE TABLE reservation_status_history (
    id              BIGSERIAL PRIMARY KEY,
    reservation_id  UUID NOT NULL REFERENCES reservation(id) ON DELETE CASCADE,
    from_status     reservation_status,
    to_status       reservation_status NOT NULL,
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by      VARCHAR(60) NOT NULL,
    comment         VARCHAR(255)
);

CREATE INDEX idx_status_history_reservation ON reservation_status_history (reservation_id);
CREATE INDEX idx_status_history_changed_at ON reservation_status_history (changed_at);

-- Payments
CREATE TABLE reservation_payment (
    id              UUID PRIMARY KEY,
    reservation_id  UUID NOT NULL UNIQUE REFERENCES reservation(id) ON DELETE CASCADE,
    amount          NUMERIC(10,2) NOT NULL,
    currency        CHAR(3) NOT NULL,
    status          payment_status NOT NULL,
    psp_intent_id   VARCHAR(255) NOT NULL,
    captured_at     TIMESTAMPTZ,
    failure_reason  VARCHAR(255)
);

CREATE INDEX idx_payment_intent ON reservation_payment (psp_intent_id);

CREATE TABLE payment_refund (
    id             UUID PRIMARY KEY,
    payment_id     UUID NOT NULL REFERENCES reservation_payment(id) ON DELETE CASCADE,
    amount         NUMERIC(10,2) NOT NULL,
    status         payment_status NOT NULL DEFAULT 'REFUNDED',
    psp_refund_id  VARCHAR(255) NOT NULL,
    processed_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payment_refund_payment ON payment_refund (payment_id);

-- Stripe webhook events
CREATE TABLE stripe_webhook_event (
    id                TEXT PRIMARY KEY,
    type              TEXT NOT NULL,
    received_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    payment_intent_id TEXT,
    payload           JSONB
);

CREATE INDEX idx_webhook_pi ON stripe_webhook_event (payment_intent_id);
-- Notifications & audit
CREATE TABLE notification_outbox (
    id               UUID PRIMARY KEY,
    reservation_id   UUID REFERENCES reservation(id) ON DELETE SET NULL,
    channel          VARCHAR(30) NOT NULL,
    template         VARCHAR(100) NOT NULL,
    payload          JSONB NOT NULL,
    status           notification_status NOT NULL DEFAULT 'PENDING',
    attempt_count    INTEGER NOT NULL DEFAULT 0,
    last_attempt_at  TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notification_status ON notification_outbox (status);
CREATE INDEX idx_notification_created_at ON notification_outbox (created_at);

CREATE TABLE audit_log (
    id           UUID PRIMARY KEY,
    user_id      UUID REFERENCES app_user(id) ON DELETE SET NULL,
    action       VARCHAR(60) NOT NULL,
    entity_type  VARCHAR(60) NOT NULL,
    entity_id    UUID,
    metadata     JSONB,
    ip_address   INET,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_user ON audit_log (user_id);
CREATE INDEX idx_audit_entity ON audit_log (entity_type, entity_id);
CREATE INDEX idx_audit_created_at ON audit_log (created_at);

COMMIT;


