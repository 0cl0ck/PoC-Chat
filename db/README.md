# Database Setup

Scripts pour provisionner les bases de données du projet **Your Car Your Way**.

---

## Structure

- `postgres/schema.sql` : DDL PostgreSQL (utilisateurs, agences, offres, réservations, paiements, notifications, audit).
- `postgres/seed.sql` : données de référence minimales (catégories ACRISS, agences, horaires, offre exemple).
- `mongo/support_conversations.json` : jeu de données support temps réel (agrégat **SupportConversation**).

---

## Pré-requis

- **PostgreSQL 15+**
- **MongoDB 6+**

---

## Déploiement PostgreSQL

```bash
psql -U <user> -d <database> -f db/postgres/schema.sql
psql -U <user> -d <database> -f db/postgres/seed.sql
```

````

Le schéma respecte les agrégats DDD (`app_user`, `reservation`, `reservation_payment`) et inclut :

- journal des statuts (`reservation_status_history`) pour l’audit fonctionnel,
- outbox (`notification_outbox`) pour les emails,
- journal d’événements Stripe (`stripe_webhook_event`) et index `idx_payment_intent` pour l’idempotence PSP.

---

## Déploiement MongoDB

```bash
mongoimport --uri "mongodb://<user>:<pwd>@<host>/<database>" \
 --collection support_conversations --file db/mongo/support_conversations.json --jsonArray
```

Le JSON importe une conversation exemple avec ses messages, à répliquer pour vos tests de messagerie support (agrégat **SupportConversation**).

````
