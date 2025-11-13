#!/bin/bash

# Reemplaza con tus datos reales
RDS_ENDPOINT="your-db-instance.cluster-xyz.us-east-1.rds.amazonaws.com"
PORT="5432"
USERNAME="postgres"
DATABASE="postgres"

echo "Probando conexión a RDS PostgreSQL..."
psql -h $RDS_ENDPOINT -p $PORT -U $USERNAME -d $DATABASE -c "SELECT version();"
