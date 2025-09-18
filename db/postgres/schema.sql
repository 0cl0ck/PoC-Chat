BEGIN;

-- ==== UTILISATEURS ===================================================
CREATE TABLE users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  
  -- BR: "informations personnelles (nom, prénom, date de naissance, adresse)"
  first_name    VARCHAR(100) NOT NULL,
  last_name     VARCHAR(100) NOT NULL,
  birth_date    DATE,
  phone         VARCHAR(30),
  address_line1 VARCHAR(255),
  address_line2 VARCHAR(255),
  city          VARCHAR(120),
  postal_code   VARCHAR(20),
  country       VARCHAR(100),
  
  email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  is_deleted     BOOLEAN NOT NULL DEFAULT FALSE, -- BR: "Supprimer son compte"
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==== AGENCES (réseau Your Car Your Way) ============================
CREATE TABLE agencies (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(150) NOT NULL,
  
  -- BR: "ville de départ / ville de retour" 
  city        VARCHAR(120) NOT NULL,
  country     VARCHAR(100) NOT NULL,
  
  -- Infos pratiques agence
  address     VARCHAR(255),
  phone       VARCHAR(30),
  email       VARCHAR(150),
  
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- BR: "Consulter la liste des agences de location"
CREATE INDEX idx_agencies_city ON agencies (city, is_active);

-- ==== CATÉGORIES VÉHICULES (norme ACRISS) ===========================
-- BR: "Les catégories du véhicule reprennent la norme ACRISS"
CREATE TABLE vehicle_categories (
  code        VARCHAR(4) PRIMARY KEY, -- Code ACRISS
  label_en    VARCHAR(150) NOT NULL,
  label_fr    VARCHAR(150) NOT NULL   -- BR: i18n EN/FR
);

-- ==== OFFRES DE LOCATION ============================================
CREATE TABLE rental_offers (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- BR: "ville de départ, ville de retour"
  pickup_agency_id  UUID NOT NULL REFERENCES agencies(id),
  dropoff_agency_id UUID NOT NULL REFERENCES agencies(id),
  
  -- BR: "date et heure de début, date et heure de retour"  
  pickup_datetime   TIMESTAMPTZ NOT NULL,
  dropoff_datetime  TIMESTAMPTZ NOT NULL,
  
  -- BR: "catégorie du véhicule"
  vehicle_category  VARCHAR(4) NOT NULL REFERENCES vehicle_categories(code),
  
  -- BR: "tarif"
  price_amount      NUMERIC(10,2) NOT NULL,
  currency          CHAR(3) NOT NULL DEFAULT 'EUR',
  
  is_available      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT chk_dates CHECK (dropoff_datetime > pickup_datetime),
  CONSTRAINT chk_price CHECK (price_amount > 0)
);

-- BR: "formulaire de recherche avec les critères"
CREATE INDEX idx_offer_search ON rental_offers (pickup_agency_id, dropoff_agency_id, pickup_datetime, vehicle_category, is_available);

-- ==== RÉSERVATIONS ===================================================
CREATE TABLE reservations (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id),
  offer_id   UUID NOT NULL REFERENCES rental_offers(id),
  
  -- Snapshot des conditions au moment de la réservation
  pickup_datetime   TIMESTAMPTZ NOT NULL,
  dropoff_datetime  TIMESTAMPTZ NOT NULL,
  pickup_agency_name VARCHAR(150) NOT NULL,
  dropoff_agency_name VARCHAR(150) NOT NULL,
  pickup_city       VARCHAR(120) NOT NULL,
  dropoff_city      VARCHAR(120) NOT NULL,
  vehicle_category  VARCHAR(150) NOT NULL,
  total_amount      NUMERIC(10,2) NOT NULL,
  currency          CHAR(3) NOT NULL,
  
  status       VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING, CONFIRMED, CANCELLED
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT chk_reservation_dates CHECK (dropoff_datetime > pickup_datetime),
  CONSTRAINT chk_total CHECK (total_amount > 0)
);

-- BR: "Consulter l'historique de ses réservations (passées et en cours)"
CREATE INDEX idx_reservations_user ON reservations (user_id, created_at DESC);
CREATE INDEX idx_reservations_dates ON reservations (pickup_datetime, dropoff_datetime);

-- ==== PAIEMENTS STRIPE ===============================================
CREATE TABLE payments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id  UUID NOT NULL UNIQUE REFERENCES reservations(id) ON DELETE CASCADE,
  amount          NUMERIC(10,2) NOT NULL,
  currency        CHAR(3) NOT NULL,
  stripe_intent_id VARCHAR(255) NOT NULL UNIQUE,
  status          VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING, CAPTURED, FAILED
  captured_at     TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT chk_payment_amount CHECK (amount > 0)
);

-- ==== REMBOURSEMENTS (BR: politique annulation 25%) =================
CREATE TABLE refunds (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id      UUID NOT NULL REFERENCES payments(id),
  amount          NUMERIC(10,2) NOT NULL, -- 25% si < 1 semaine
  stripe_refund_id VARCHAR(255) NOT NULL UNIQUE,
  reason          VARCHAR(100), -- 'CANCELLATION', 'MODIFICATION'  
  processed_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT chk_refund_amount CHECK (amount > 0)
);

-- ==== WEBHOOKS STRIPE ================================================
CREATE TABLE stripe_webhook_events (
  id         TEXT PRIMARY KEY, -- Stripe event ID
  type       TEXT NOT NULL,
  payload    JSONB NOT NULL,
  processed  BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_webhook_processed ON stripe_webhook_events (processed, created_at);

-- ==== NOTIFICATIONS EMAIL ============================================
-- BR: "Recevoir un email de confirmation après réservation"
-- BR: "Recevoir un email en cas de modification ou annulation"  
CREATE TABLE email_notifications (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id UUID REFERENCES reservations(id) ON DELETE SET NULL,
  recipient      VARCHAR(255) NOT NULL,
  template_type  VARCHAR(50) NOT NULL, -- 'CONFIRMATION', 'MODIFICATION', 'CANCELLATION'
  template_data  JSONB NOT NULL,
  status         VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING, SENT, FAILED
  sent_at        TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_pending ON email_notifications (status, created_at) WHERE status = 'PENDING';

-- ==== DONNÉES DE RÉFÉRENCE ===========================================
-- BR: norme ACRISS obligatoire
INSERT INTO vehicle_categories (code, label_en, label_fr) VALUES
  ('ECAR', 'Economy Car', 'Voiture Économique'),
  ('CCAR', 'Compact Car', 'Voiture Compacte'), 
  ('ICAR', 'Intermediate Car', 'Voiture Intermédiaire'),
  ('SCAR', 'Standard Car', 'Voiture Standard'),
  ('FCAR', 'Full Size Car', 'Voiture Grande Taille'),
  ('PCAR', 'Premium Car', 'Voiture Premium'),
  ('LCAR', 'Luxury Car', 'Voiture de Luxe');

-- Exemples d'agences (réseau international)
INSERT INTO agencies (name, city, country, address, phone, email) VALUES
  ('Your Car Your Way London', 'London', 'United Kingdom', '123 Oxford Street', '+44 20 1234 5678', 'london@yourcar.com'),
  ('Your Car Your Way Paris', 'Paris', 'France', '456 Champs-Élysées', '+33 1 23 45 67 89', 'paris@yourcar.com'),
  ('Your Car Your Way Berlin', 'Berlin', 'Germany', '789 Unter den Linden', '+49 30 1234 5678', 'berlin@yourcar.com'),
  ('Your Car Your Way Madrid', 'Madrid', 'Spain', '321 Gran Vía', '+34 91 123 45 67', 'madrid@yourcar.com'),
  ('Your Car Your Way New York', 'New York', 'United States', '654 5th Avenue', '+1 212 123 4567', 'newyork@yourcar.com'),
  ('Your Car Your Way Los Angeles', 'Los Angeles', 'United States', '987 Sunset Boulevard', '+1 323 123 4567', 'la@yourcar.com');

-- ==== VUES POUR SIMPLIFIER LES REQUÊTES =============================

-- Vue pour la recherche d'offres (BR: formulaire de recherche)
CREATE VIEW offer_search AS
SELECT 
  ro.id,
  ro.pickup_datetime,
  ro.dropoff_datetime,
  ro.price_amount,
  ro.currency,
  
  ap.city AS pickup_city,
  ap.name AS pickup_agency,
  ad.city AS dropoff_city,
  ad.name AS dropoff_agency,
  
  vc.code AS vehicle_code,
  vc.label_en AS vehicle_category_en,
  vc.label_fr AS vehicle_category_fr,
  
  ro.is_available
  
FROM rental_offers ro
  JOIN agencies ap ON ro.pickup_agency_id = ap.id
  JOIN agencies ad ON ro.dropoff_agency_id = ad.id
  JOIN vehicle_categories vc ON ro.vehicle_category = vc.code
WHERE ro.is_available = TRUE;

-- Vue pour l'historique des réservations (BR: historique passées et en cours)
CREATE VIEW reservation_history AS
SELECT 
  r.id,
  r.pickup_datetime,
  r.dropoff_datetime,
  r.pickup_city,
  r.dropoff_city,
  r.pickup_agency_name,
  r.dropoff_agency_name,
  r.vehicle_category,
  r.total_amount,
  r.currency,
  r.status,
  r.created_at,
  
  u.email,
  u.first_name,
  u.last_name,
  
  p.status AS payment_status
  
FROM reservations r
  JOIN users u ON r.user_id = u.id
  LEFT JOIN payments p ON r.id = p.reservation_id;

COMMIT;