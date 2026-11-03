const target = db.getSiblingDB("Ordini");

["data-ingest-ordini-mysql", "data-ingest-ordini-postgres", "ordini"].forEach((name) => {
  if (!target.getCollectionNames().includes(name)) {
    target.createCollection(name);
  }
});

target.getCollection("ordini").createIndex({ order_date: -1 });
target.getCollection("ordini").createIndex({ source_system: 1, status: 1 });
