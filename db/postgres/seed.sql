-- Seed data for Your Car Your Way transactional database
-- Reference values for categories, agencies, and schedules

BEGIN;

-- Vehicle categories (ACRISS standard sample)
INSERT INTO vehicle_category (code_acriss, segment, label_en, label_fr) VALUES
    ('CDMR', 'Compact', 'Compact 4dr Manual AC', 'Compact 4 portes Manuel AC'),
    ('IDAR', 'Intermediate', 'Intermediate 4dr Automatic AC', 'Intermédiaire 4 portes Automatique AC'),
    ('SFAR', 'Standard SUV', 'Standard SUV Automatic AC', 'SUV Standard Automatique AC'),
    ('FVMR', 'Fullsize Van', 'Fullsize Van Manual AC', 'Van Grande Taille Manuel AC');

-- Rental agencies (simplified set for seed)
INSERT INTO rental_agency (id, name, phone_support, email_support, timezone)
VALUES
    ('11111111-1111-1111-1111-111111111111', 'London City Center', '+44 20 7946 001', 'support-lon@ycw.com', 'Europe/London'),
    ('22222222-2222-2222-2222-222222222222', 'Paris Gare du Nord', '+33 1 42 81 002', 'support-par@ycw.com', 'Europe/Paris');

INSERT INTO agency_location (id, agency_id, line1, line2, city, postal_code, country_iso, latitude, longitude)
VALUES
    ('31111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', '10 Down Street', NULL, 'London', 'SW1A 2AA', 'GB', 51.5033, -0.1276),
    ('32222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', '16 Rue du Faubourg', NULL, 'Paris', '75010', 'FR', 48.8809, 2.3553);

INSERT INTO agency_schedule (id, agency_id, weekday, opens_at, closes_at, closed_all_day)
VALUES
    ('41111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 0, '08:00', '20:00', FALSE),
    ('41111111-1111-1111-1111-111111111112', '11111111-1111-1111-1111-111111111111', 6, '09:00', '18:00', FALSE),
    ('42222222-2222-2222-2222-222222222221', '22222222-2222-2222-2222-222222222222', 0, '08:00', '20:00', FALSE),
    ('42222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', 6, '09:00', '18:00', FALSE);

-- Sample rental offer for testing search queries
INSERT INTO rental_offer (
    id, agency_pickup_id, agency_dropoff_id, code_acriss,
    pickup_at, dropoff_at, base_price_amount, currency, stock_total, last_sync_at
) VALUES (
    '51111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    'CDMR',
    '2025-10-01 09:00+01',
    '2025-10-05 10:00+02',
    199.99,
    'EUR',
    5,
    NOW()
);

COMMIT;
