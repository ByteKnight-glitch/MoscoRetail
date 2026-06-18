#!/bin/bash
STACK_NAME="vpc-MoscoRetail"
TEMPLATE_FILE="vpc-MoscoRetail.yaml"
REGION="us-east-1"

echo "--- Desplegando infraestructura de red en $REGION ---"

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: no se encuentra el archivo $TEMPLATE_FILE."
    exit 1
fi

echo "Creando stack..."
aws cloudformation create-stack \
    --region "$REGION" \
    --stack-name "$STACK_NAME" \
    --template-body "file://$TEMPLATE_FILE"

if [ $? -eq 0 ]; then
    echo "Stack enviado correctamente a $REGION."
else
    echo "Error al iniciar el despliegue."
    exit 1
fi

echo "Generando clave SSH de forma automática..."
ssh-keygen -t ed25519 -f "./MoscoRetail.pem" -N ""
