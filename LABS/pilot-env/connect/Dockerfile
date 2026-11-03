FROM quay.io/debezium/connect:2.7.3.Final

ARG MONGO_KAFKA_CONNECT_VERSION=1.13.0

# Debezium has no MongoDB sink: add the official MongoDB Kafka Connector (all-in-one jar)
USER root
RUN mkdir -p /kafka/connect/mongo-kafka-connect \
 && curl -fsSL -o /kafka/connect/mongo-kafka-connect/mongo-kafka-connect-all.jar \
    https://repo1.maven.org/maven2/org/mongodb/kafka/mongo-kafka-connect/${MONGO_KAFKA_CONNECT_VERSION}/mongo-kafka-connect-${MONGO_KAFKA_CONNECT_VERSION}-all.jar \
 && chown -R kafka:kafka /kafka/connect/mongo-kafka-connect
USER kafka
