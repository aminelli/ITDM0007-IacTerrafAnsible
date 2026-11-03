FROM python:3.12-slim

RUN pip install --no-cache-dir requests==2.32.3 pymysql==1.1.1 cryptography==43.0.3 psycopg2-binary==2.9.10 pymongo==4.10.1

WORKDIR /app
COPY tools/generator /app/generator
COPY tools/init /app/init
COPY connect/connectors /app/connectors
