# Ambiente Pilot DataOps – Ordini (MySQL / PostgreSQL → Kafka → MongoDB → NiFi → Metabase)

Ambiente pilot completo, eseguibile con **Docker Desktop su Windows**, per acquisire ordini da due sorgenti relazionali
con strutture diverse, trasportarli in CDC su Kafka, depositarli in MongoDB, uniformarli con Apache NiFi e analizzarli in BI e real-time.

> **Nota di progetto – Superset sostituito da Metabase.** Su indicazione concordata, Apache Superset è sostituito da
> **Metabase OSS**: supporta nativamente MongoDB (Superset richiede una sorgente SQL), permette query aggregate native,
> dashboard BI e dashboard con auto-refresh per il monitoraggio real-time.

## Indice

- [Ambiente Pilot DataOps – Ordini (MySQL / PostgreSQL → Kafka → MongoDB → NiFi → Metabase)](#ambiente-pilot-dataops--ordini-mysql--postgresql--kafka--mongodb--nifi--metabase)
  - [Indice](#indice)
  - [1. Architettura](#1-architettura)
  - [2. Prerequisiti](#2-prerequisiti)
  - [3. Struttura del progetto](#3-struttura-del-progetto)
  - [4. Avvio, stop, distruzione](#4-avvio-stop-distruzione)
    - [4.1 Creazione e avvio](#41-creazione-e-avvio)
    - [4.2 Stop e riavvio (dati conservati)](#42-stop-e-riavvio-dati-conservati)
    - [4.3 Stop temporaneo dei soli generatori](#43-stop-temporaneo-dei-soli-generatori)
    - [4.4 Distruzione completa (container, rete, volumi, dati)](#44-distruzione-completa-container-rete-volumi-dati)
    - [4.5 Reset di un solo componente](#45-reset-di-un-solo-componente)
  - [5. Servizi, porte e credenziali](#5-servizi-porte-e-credenziali)
  - [6. Modello dati](#6-modello-dati)
    - [6.1 MySQL (`sales_mysql`)](#61-mysql-sales_mysql)
    - [6.2 PostgreSQL (`sales_postgres`)](#62-postgresql-sales_postgres)
    - [6.3 Schema JSON uniforme (collection `ordini`)](#63-schema-json-uniforme-collection-ordini)
  - [7. Pattern Outbox e CDC Debezium](#7-pattern-outbox-e-cdc-debezium)
  - [8. MongoDB](#8-mongodb)
  - [9. Pipeline NiFi (ETL)](#9-pipeline-nifi-etl)
  - [10. Metabase: dashboard BI e real-time](#10-metabase-dashboard-bi-e-real-time)
  - [11. Comandi CLI Kafka per monitorare i topic](#11-comandi-cli-kafka-per-monitorare-i-topic)
  - [12. Comandi utili di verifica](#12-comandi-utili-di-verifica)
  - [13. Test automatico dell'intero ciclo](#13-test-automatico-dellintero-ciclo)
  - [14. Troubleshooting](#14-troubleshooting)
    - [14.1 Topic Kafka vuoti: connettori non registrati](#141-topic-kafka-vuoti-connettori-non-registrati)

---

## 1. Architettura

```
 order-generator-mysql (5s)                         order-generator-postgres (6s)
          │ INSERT orders+order_items+order_outbox            │ INSERT sales_orders+sales_order_lines+order_outbox
          ▼ (1 transazione)                                   ▼ (1 transazione)
      ┌────────┐                                          ┌──────────┐
      │ MySQL  │                                          │ Postgres │
      └───┬────┘                                          └────┬─────┘
          │ binlog                                             │ WAL (pgoutput)
          ▼                                                    ▼
   Debezium MySQL source  ───────────┐        ┌─────────── Debezium Postgres source
   (EventRouter / outbox)            ▼        ▼            (EventRouter / outbox)
                              ┌───────────────────────┐
                              │ Kafka (KRaft)         │
                              │  ordini-mysql         │
                              │  ordini-postgres      │
                              └──────────┬────────────┘
                                         │ MongoDB Kafka Connector (sink)
                                         ▼
                  ┌────────────────────────────────────────────┐
                  │ MongoDB – database "Ordini"                │
                  │  data-ingest-ordini-mysql      (raw)       │
                  │  data-ingest-ordini-postgres   (raw)       │
                  │  ordini                        (uniforme)  │◄──┐
                  └──────────┬─────────────────────────────────┘   │
                             │ polling 5s (GetMongo)               │ PutMongo (upsert)
                             ▼                                     │
                    Apache NiFi: Jolt ETL  ────────────────────────┘
                                                                   
                  MongoDB.ordini ──► Metabase (dashboard BI + real-time)
```

Container (nome → ruolo):

| Container                        | Immagine                     | Ruolo                                              |
| -------------------------------- | ---------------------------- | -------------------------------------------------- |
| `pilot-mysql`                    | `mysql:8.0`                  | Sorgente 1 (binlog ROW abilitato)                  |
| `pilot-postgres`                 | `postgres:16`                | Sorgente 2 (`wal_level=logical`)                   |
| `pilot-kafka`                    | `apache/kafka:3.9.0`         | Broker Kafka KRaft (senza ZooKeeper)               |
| `pilot-kafka-init`               | `apache/kafka:3.9.0`         | Job one-shot: crea i topic                         |
| `pilot-connect`                  | build `connect/Dockerfile`   | Kafka Connect: Debezium + MongoDB Kafka Connector  |
| `pilot-connect-init`             | build `tools/Dockerfile`     | Job one-shot: registra i 4 connettori              |
| `pilot-mongodb`                  | `mongo:7`                    | Database `Ordini`                                  |
| `pilot-nifi`                     | `apache/nifi:1.28.1`         | ETL                                                |
| `pilot-nifi-init`                | build `tools/Dockerfile`     | Job one-shot: crea e avvia il flow via REST API    |
| `pilot-metabase`                 | `metabase/metabase:v0.50.26` | BI e real-time                                     |
| `pilot-metabase-init`            | build `tools/Dockerfile`     | Job one-shot: utente admin, data source, dashboard |
| `pilot-order-generator-mysql`    | build `tools/Dockerfile`     | Genera 1 ordine ogni 5 s su MySQL                  |
| `pilot-order-generator-postgres` | build `tools/Dockerfile`     | Genera 1 ordine ogni 6 s su PostgreSQL             |

## 2. Prerequisiti

- Windows 10/11 con **Docker Desktop** (backend WSL2) avviato; Docker Compose v2.
- Risorse consigliate per Docker Desktop: **≥ 6 GB RAM**, 4 CPU, ~10 GB disco. NiFi e Kafka Connect sono i servizi più pesanti.
- Porte libere sull'host: `3306, 5432, 29092, 8083, 27017, 8081, 3000` (modificabili in `.env`).
- Accesso a Internet per scaricare immagini e il jar MongoDB Kafka Connector (Maven Central).
- PowerShell 5.1+ per lo script di test.

Verifica:

```powershell
docker version
docker compose version
```

## 3. Struttura del progetto

```
pilot-env/
├── docker-compose.yml          # definizione di tutti i servizi
├── .env                        # credenziali, porte, intervalli dei generatori
├── mysql/init/01-schema.sql    # schema MySQL + utente debezium
├── postgres/init/01-schema.sql # schema PostgreSQL
├── mongo/init/01-init.js       # database Ordini + 3 collection + indici
├── connect/
│   ├── Dockerfile              # Debezium Connect + MongoDB Kafka Connector
│   └── connectors/*.json       # 4 connettori (2 source Debezium, 2 sink Mongo)
├── tools/
│   ├── Dockerfile              # immagine Python condivisa (generatori + job di init)
│   ├── generator/order_generator.py
│   └── init/{register_connectors,nifi_flow,metabase_setup}.py
└── scripts/test-cycle.ps1      # test automatico crea → verifica → distrugge
```

## 4. Avvio, stop, distruzione

Tutti i comandi vanno eseguiti in `pilot-env\`.

### 4.1 Creazione e avvio

```powershell
cd pilot-env
docker compose up -d --build
```

L'ordine di avvio è garantito da `depends_on` + healthcheck. Il primo avvio richiede alcuni minuti
(download immagini, build, inizializzazione MySQL, avvio NiFi ~1-2 min). Al termine i job `*-init` risultano `Exited (0)`.

```powershell
docker compose ps -a
docker compose logs connect-init nifi-init metabase-init   # esito della configurazione automatica
```

### 4.2 Stop e riavvio (dati conservati)

```powershell
docker compose stop        # ferma
docker compose start       # riavvia (i job di init sono idempotenti)
```

### 4.3 Stop temporaneo dei soli generatori

```powershell
docker compose stop order-generator-mysql order-generator-postgres
docker compose start order-generator-mysql order-generator-postgres
```

Cambiare la frequenza: modificare `MYSQL_GENERATOR_INTERVAL` / `POSTGRES_GENERATOR_INTERVAL` in `.env`, poi
`docker compose up -d order-generator-mysql order-generator-postgres`.

### 4.4 Distruzione completa (container, rete, volumi, dati)

```powershell
docker compose down -v --remove-orphans
```

Opzionale, per rimuovere anche le immagini costruite:

```powershell
docker rmi orders-pilot-tools:latest orders-pilot-connect:latest
```

> `docker compose down` **senza** `-v` conserva i volumi: al successivo `up` i dati e i connettori (salvati nei topic
> interni di Kafka) sono ancora presenti. NiFi non ha volume: il flow viene ricreato da `nifi-init`.

### 4.5 Reset di un solo componente

```powershell
docker compose rm -sf nifi nifi-init; docker compose up -d nifi-init   # ricrea il flow NiFi
```

## 5. Servizi, porte e credenziali

| Servizio            | URL / host                                                   | Utente                                  | Password                     |
| ------------------- | ------------------------------------------------------------ | --------------------------------------- | ---------------------------- |
| MySQL               | `localhost:3306`, db `sales_mysql`                           | `root` / `debezium`                     | `mysql_root_pwd` / `dbz_pwd` |
| PostgreSQL          | `localhost:5432`, db `sales_postgres`                        | `pilot`                                 | `pilot_pwd`                  |
| Kafka (host)        | `localhost:29092`                                            | –                                       | –                            |
| Kafka (rete Docker) | `kafka:9092`                                                 | –                                       | –                            |
| Kafka Connect REST  | http://localhost:8083                                        | –                                       | –                            |
| MongoDB             | `mongodb://root:mongo_pwd@localhost:27017/?authSource=admin` | `root`                                  | `mongo_pwd`                  |
| NiFi                | http://localhost:8081/nifi                                   | (HTTP senza autenticazione, solo pilot) | –                            |
| Metabase            | http://localhost:3000                                        | `admin@example.com`                     | `Pilot-Admin#2024`           |

> ⚠️ Credenziali in chiaro e NiFi senza autenticazione: **solo per ambiente pilot locale**.

## 6. Modello dati

Le due sorgenti hanno **volutamente strutture diverse** (nomi, tipi, annidamento, valori di stato).

### 6.1 MySQL (`sales_mysql`)

| Tabella        | Colonne principali                                                                                                                                                                                             |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `orders`       | `order_id` (PK, AI), `customer_code`, `customer_name`, `order_datetime` (DATETIME), `order_status` (ENUM `NEW/PAID/SHIPPED/CANCELLED`), `net_amount`, `tax_amount`, `total_amount`, `currency`, `ship_country` |
| `order_items`  | `item_id` (PK), `order_id` (FK), `line_no`, `product_sku`, `product_name`, `quantity`, `unit_price`, `line_total`                                                                                              |
| `order_outbox` | `id`, `aggregate_type`, `aggregate_id`, `event_type`, `payload` (JSON), `created_at`                                                                                                                           |

### 6.2 PostgreSQL (`sales_postgres`)

| Tabella             | Colonne principali                                                                                                                                                                                                    |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sales_orders`      | `id` (PK, bigserial), `customer_id` (UUID), `customer_full_name`, `created_at` (TIMESTAMPTZ), `state` (`created/paid/shipped/cancelled`), `amount_net`, `amount_vat`, `amount_gross`, `currency_code`, `country_code` |
| `sales_order_lines` | `line_id` (PK), `order_id` (FK), `line_number`, `item_code`, `item_description`, `qty`, `price_net`, `line_net`                                                                                                       |
| `order_outbox`      | `id`, `aggregate_type`, `aggregate_id`, `event_type`, `payload` (JSONB), `created_at`                                                                                                                                 |

### 6.3 Schema JSON uniforme (collection `ordini`)

```json
{
  "_id": "POSTGRES-5",
  "source_system": "POSTGRES",
  "source_order_id": 5,
  "customer": { "code": "c26abb20-...", "name": "Acme Corp" },
  "order_date": "2026-10-15T09:19:39.198Z",
  "status": "NEW",
  "total_net": 1384.6,
  "total_vat": 304.61,
  "total_gross": 1689.21,
  "currency": "EUR",
  "country": "NL",
  "items": [
    { "line_number": 1, "sku": "SKU-1005", "description": "27 inch Monitor",
      "quantity": 5, "unit_price": 249, "line_total": 1245 }
  ],
  "etl_processed_at": "2026-10-15T09:44:27Z"
}
```

Mapping principali: `order_status`/`state` → `status` (valori normalizzati `NEW|PAID|SHIPPED|CANCELLED`);
`total_amount`/`amount_gross` → `total_gross`; `items`/`lines` → `items`; `customer_*`/`customer.*` → `customer.{code,name}`.
(Per PostgreSQL `customer.code` è l'UUID del cliente, unico identificativo disponibile in quella sorgente.)

## 7. Pattern Outbox e CDC Debezium

Debezium emette un evento **per tabella**, quindi ordine e righe finirebbero in messaggi separati. Per avere
**un solo JSON con ordine + righe** sul topic si usa il pattern **Transactional Outbox**:

1. il generatore, nella **stessa transazione**, inserisce `orders` + `order_items` e una riga in `order_outbox`
   il cui `payload` è l'aggregato completo (ordine con righe annidate);
2. Debezium cattura (binlog MySQL / WAL PostgreSQL) **solo** `order_outbox` e, tramite la SMT
   `io.debezium.transforms.outbox.EventRouter`, pubblica il `payload` espanso come JSON sul topic
   `ordini-mysql` / `ordini-postgres`, con chiave = id ordine;
3. il **MongoDB Kafka Connector** (sink) scrive ogni messaggio nella collection `data-ingest-ordini-*` con
   `_id` = id ordine (SMT `HoistField$Key` + `ProvidedInKeyStrategy`) e `ReplaceOne` con upsert (**idempotente**).

> Debezium non ha un sink MongoDB: la parte "sink" usa il connettore ufficiale MongoDB, eseguito nello stesso Kafka Connect
> (jar aggiunto in `connect/Dockerfile`).

Connettori registrati (`connect/connectors/`):

| Nome                                     | Tipo                                                     | Flusso                                                   |
| ---------------------------------------- | -------------------------------------------------------- | -------------------------------------------------------- |
| `debezium-mysql-orders-source`           | Debezium MySQL                                           | MySQL → `ordini-mysql`                                   |
| `debezium-postgres-orders-source`        | Debezium PostgreSQL (`pgoutput`, slot `debezium_orders`) | Postgres → `ordini-postgres`                             |
| `mongo-sink-data-ingest-ordini-mysql`    | MongoDB sink                                             | `ordini-mysql` → `Ordini.data-ingest-ordini-mysql`       |
| `mongo-sink-data-ingest-ordini-postgres` | MongoDB sink                                             | `ordini-postgres` → `Ordini.data-ingest-ordini-postgres` |

Comandi Kafka Connect REST:

```powershell
curl http://localhost:8083/connectors
curl http://localhost:8083/connectors/debezium-mysql-orders-source/status
curl -X POST http://localhost:8083/connectors/debezium-mysql-orders-source/restart
curl -X DELETE http://localhost:8083/connectors/mongo-sink-data-ingest-ordini-mysql
# ri-registrazione di tutti i connettori
docker compose up -d connect-init
```

## 8. MongoDB

Database **`Ordini`** con 3 collection (create da `mongo/init/01-init.js`):

- `data-ingest-ordini-mysql` – ordini grezzi da MySQL (con `items`)
- `data-ingest-ordini-postgres` – ordini grezzi da PostgreSQL (con `lines`)
- `ordini` – ordini uniformati dal flow NiFi

```powershell
docker exec -it pilot-mongodb mongosh -u root -p mongo_pwd --authenticationDatabase admin Ordini
```
```js
db.getCollectionNames()
db.getCollection("data-ingest-ordini-mysql").countDocuments()
db.getCollection("data-ingest-ordini-postgres").findOne()
db.ordini.find().sort({order_date: -1}).limit(3)
db.ordini.aggregate([{$group: {_id: "$source_system", n: {$sum: 1}, revenue: {$sum: "$total_gross"}}}])
```

Dopo l'ETL, NiFi marca i documenti sorgente con `etl_status: "DONE"` e `etl_processed_at`.

## 9. Pipeline NiFi (ETL)

NiFi 1.28.1 gira in HTTP (porta host 8081). Il flow viene creato in automatico da `nifi-init` nel process group **`orders-etl`**,
con due rami identici (uno per sorgente), 7 processori ciascuno:

| #   | Processore                            | Funzione                                                                                                           |
| --- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| 1   | `GetMongo` (`read-<src>-ingest`)      | Polling ogni 5 s su `data-ingest-ordini-<src>`, query `{"etl_status": {"$exists": false}}`, un FlowFile per ordine |
| 2   | `EvaluateJsonPath`                    | Estrae `$[0]._id` nell'attributo `src_pk`                                                                          |
| 3   | `UpdateAttribute`                     | Imposta `etl_ts` (timestamp UTC dell'ETL)                                                                          |
| 4   | `JoltTransformJSON`                   | **ETL**: uniforma la struttura JSON (spec Jolt diversa per sorgente)                                               |
| 5   | `PutMongo` (`upsert-<src>-in-ordini`) | Upsert in `Ordini.ordini` (chiave `_id` = `MYSQL-<id>` / `POSTGRES-<id>`)                                          |
| 6   | `ReplaceText`                         | Costruisce `{"$set":{"etl_status":"DONE",...}}`                                                                    |
| 7   | `PutMongo` (`mark-<src>-ingest-done`) | Marca il documento sorgente come processato                                                                        |

**Trigger sulle collection**: NiFi non riceve notifiche da MongoDB; il "trigger" è un polling incrementale a 5 s,
reso incrementale dal flag `etl_status`. Le relazioni `failure` sono auto-terminate: se un passo fallisce il documento sorgente
**non** viene marcato e viene riprovato al polling successivo (upsert idempotente).

Controllo e uso:

```powershell
curl http://localhost:8081/nifi-api/flow/about
# UI: http://localhost:8081/nifi  → process group "orders-etl"
```

Per modificare le spec Jolt: UI NiFi → processore `unify-*-json`, oppure editare `tools/init/nifi_flow.py` e ricreare il flow (§4.5).

## 10. Metabase: dashboard BI e real-time

URL: http://localhost:3000 (login `admin@example.com` / `Pilot-Admin#2024`). Data source **"Ordini (MongoDB)"** collegata al database
`Ordini`; tutte le card usano query native (aggregation pipeline) sulla collection `ordini`. Collection Metabase: **Orders Pilot**.

**Dashboard "Orders BI Analysis"** (analisi BI): totale ordini, ricavi totali, valore medio ordine, ricavi per sorgente (torta),
ordini per stato, ricavi per giorno, top 10 prodotti, top 10 clienti, ricavi per paese.

**Dashboard "Orders Real-Time Monitor"** (monitoraggio ordini in arrivo): ordini e ricavi ultimi 5 minuti, latenza media di ingestione
(data ordine → fine ETL, ultimi 5 min), ordini al minuto (ultimi 30 min), ordini ultimi 5 min per sorgente, ultimi 20 ordini.

Per l'aggiornamento automatico apri il dashboard con il parametro di refresh (secondi):
`http://localhost:3000/dashboard/3#refresh=5` (gli id esatti sono stampati da `docker compose logs metabase-init`).

## 11. Comandi CLI Kafka per monitorare i topic

I topic sono `ordini-mysql` e `ordini-postgres` (3 partizioni, chiave = id ordine).
Gli script Kafka sono nel container `pilot-kafka` (`/opt/kafka/bin`), bootstrap interno `kafka:9092` (o `localhost:9092` dentro il container).

```powershell
# Elenco e dettaglio topic
docker exec pilot-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
docker exec pilot-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic ordini-mysql

# Client consumer: ordini in arrivo (solo nuovi messaggi) – CTRL+C per uscire
docker exec -it pilot-kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic ordini-mysql
docker exec -it pilot-kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic ordini-postgres

# Dall'inizio, con chiave, partizione e timestamp
docker exec -it pilot-kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic ordini-mysql --from-beginning --property print.key=true --property print.partition=true --property print.timestamp=true

# Entrambi i topic insieme (regex)
docker exec -it pilot-kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --include "ordini-(mysql|postgres)" --property print.topic=true 2>$null

# Solo N messaggi con timeout
docker exec pilot-kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic ordini-postgres --from-beginning --max-messages 3 --timeout-ms 20000

# Consumer group persistente (monitoraggio con offset) e relativo lag
docker exec -it pilot-kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic ordini-mysql --group monitor-ordini --from-beginning
docker exec pilot-kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group monitor-ordini
docker exec pilot-kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list

# Offset (numero messaggi) per partizione
docker exec pilot-kafka /opt/kafka/bin/kafka-get-offsets.sh --bootstrap-server localhost:9092 --topic ordini-mysql
```

Dall'host Windows (porta esterna `29092`) serve un client Kafka locale, ad es.:
`kafka-console-consumer.bat --bootstrap-server localhost:29092 --topic ordini-mysql`.

Per un output JSON leggibile (PowerShell):

```powershell
docker exec pilot-kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic ordini-mysql --max-messages 1 --from-beginning --timeout-ms 20000 | ConvertFrom-Json | ConvertTo-Json -Depth 6
```

## 12. Comandi utili di verifica

```powershell
# MySQL
docker exec pilot-mysql mysql -uroot -pmysql_root_pwd -e "SELECT COUNT(*) FROM sales_mysql.orders; SELECT * FROM sales_mysql.orders ORDER BY order_id DESC LIMIT 3;"
# PostgreSQL
docker exec pilot-postgres psql -U pilot -d sales_postgres -c "SELECT COUNT(*) FROM sales_orders;"
docker exec pilot-postgres psql -U pilot -d sales_postgres -c "SELECT slot_name, active FROM pg_replication_slots;"
# Log generatori
docker logs -f pilot-order-generator-mysql
docker logs -f pilot-order-generator-postgres
# Log Kafka Connect
docker logs -f pilot-connect
# Stato complessivo
docker compose ps -a
```

## 13. Test automatico dell'intero ciclo

Lo script [`scripts/test-cycle.ps1`](pilot-env/scripts/test-cycle.ps1) esegue in automatico:
**pulizia → build → avvio → test di ogni servizio → distruzione → verifica pulizia**.

```powershell
cd pilot-env
powershell -ExecutionPolicy Bypass -File scripts\test-cycle.ps1            # ciclo completo, termina distruggendo
powershell -ExecutionPolicy Bypass -File scripts\test-cycle.ps1 -KeepRunning   # lascia l'ambiente attivo
```

Verifiche eseguite: container healthy e job di init con exit 0; popolamento e cadenza dei generatori (5 s / 6 s);
4 connettori `RUNNING`; presenza dei topic e messaggio con ordine + righe; collection MongoDB `data-ingest-*` popolate;
flow NiFi con 14 processori `RUNNING`; collection `ordini` con **schema uniforme** per entrambe le sorgenti e backlog drenato;
crescita continua di `ordini` (real-time); login Metabase, 2 dashboard e **ogni card interrogata con successo**;
consumer Kafka CLI; infine `down -v` e verifica assenza di container, volumi e rete. Codice di uscita 0 = tutto ok.

## 14. Troubleshooting

| Sintomo                                                        | Causa / rimedio                                                                                                                                                               |
| -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `failed to connect to the docker API`                          | Docker Desktop non avviato.                                                                                                                                                   |
| MySQL `unhealthy` al primo avvio                               | Init lento su dischi lenti (healthcheck tollera ~10 min). Se il volume risulta corrotto dopo un'interruzione: `docker compose down -v` e ripartire.                           |
| Connettore `FAILED`                                            | `curl http://localhost:8083/connectors/<nome>/status` (campo `trace`), correggere, poi `docker compose up -d connect-init`.                                                   |
| `ordini` non cresce                                            | Controllare processori NiFi (UI) e `docker logs pilot-nifi`; verificare backlog: `db.getCollection('data-ingest-ordini-mysql').countDocuments({etl_status:{$exists:false}})`. |
| Dashboard Metabase vuote                                       | Attendere i primi ordini uniformati; ricaricare. Le card real-time mostrano solo gli ultimi 5/30 minuti: se i generatori sono fermi risultano vuote.                          |
| Porta occupata                                                 | Cambiare `PORT_*` in `.env`.                                                                                                                                                  |
| Topic Kafka vuoti (offset 0) / nessun ordine su `ordini-*` | Connettori non registrati: vedi [14.1](#141-topic-kafka-vuoti-connettori-non-registrati). |
| Slot PostgreSQL che cresce a generatori attivi e Connect fermo | Normale: lo slot trattiene WAL finché Debezium non legge. Nel pilot `down -v` elimina tutto.                                                                                  |
| Metabase "sync" lento                                          | Il data source MongoDB viene sincronizzato in background; non blocca le query native.                                                                                         |

### 14.1 Topic Kafka vuoti: connettori non registrati

**Sintomo:** gli ordini vengono creati in MySQL/PostgreSQL ma sui topic `ordini-mysql` / `ordini-postgres` non arriva nulla
(offset a 0) e le collection `data-ingest-*` restano vuote.

**Causa tipica:** il job one-shot `pilot-connect-init` (che registra i 4 connettori in Kafka Connect) è rimasto in stato
`Created` o è terminato con errore, ad esempio per un `docker compose up` interrotto. Senza connettori nessuno legge le tabelle `order_outbox`.

**Diagnosi:**

```powershell
cd pilot-env
docker compose ps -a                          # i job *-init devono essere "Exited (0)", mai "Created"
curl.exe http://localhost:8083/connectors     # deve elencare 4 connettori; "[]" = nessun connettore registrato
docker exec pilot-kafka /opt/kafka/bin/kafka-get-offsets.sh --bootstrap-server localhost:9092 --topic ordini-mysql
```

**Soluzione** (idempotente, si può rilanciare senza effetti collaterali):

```powershell
cd pilot-env
docker compose up -d connect-init
docker logs pilot-connect-init                # attesi 4 "RUNNING"
curl.exe http://localhost:8083/connectors     # i 4 connettori
```

**Verifica:** gli offset devono crescere (Debezium recupera anche gli ordini già presenti nelle tabelle outbox):

```powershell
foreach ($t in 'ordini-mysql','ordini-postgres') {
  docker exec pilot-kafka /opt/kafka/bin/kafka-get-offsets.sh --bootstrap-server localhost:9092 --topic $t
}
```

Se un connettore risulta `FAILED`, leggere il campo `trace` con
`curl.exe http://localhost:8083/connectors/<nome>/status` e riavviarlo con
`curl.exe -X POST http://localhost:8083/connectors/<nome>/restart?includeTasks=true`.

**Prevenzione:** dopo ogni avvio verificare che tutti i job `*-init` siano `Exited (0)`
(`docker compose ps -a`) oppure eseguire lo script di test (§13).

