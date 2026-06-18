#!/bin/bash
# =========================================================================
# FASE 5/6 - REPLICACION DE DESASTRES (DR)
# Copia de Infraestructura: us-east-1 -> us-west-2 (Oregon)
# =========================================================================

ORIGEN_REGION="us-east-1"
DR_REGION="us-west-2"
export AWS_PAGER=""

echo "========================================================================="
echo " INICIANDO REPLICACION DE INFRAESTRUCTURA EN REGION DE RESPALDO"
echo "========================================================================="

# 1. Crear la VPC en la region secundaria con el mismo template
echo "-- Desplegando VPC en $DR_REGION..."
aws cloudformation create-stack \
    --region "$DR_REGION" \
    --stack-name "vpc-MoscoRetail-DR" \
    --template-body "file://vpc-MoscoRetail.yaml"

# 2. Obtener los IDs de las AMIs en la region de origen (Virginia)
echo "-- Buscando AMIs en $ORIGEN_REGION..."
AMI_LINUX_ID=$(aws ec2 describe-images \
    --region "$ORIGEN_REGION" \
    --filters "Name=name,Values=MoscoRetail-Linux-Server-AMI" \
    --query "Images[0].ImageId" \
    --output text)

AMI_WINDOWS_ID=$(aws ec2 describe-images \
    --region "$ORIGEN_REGION" \
    --filters "Name=name,Values=MoscoRetail-Windows-Server-AMI" \
    --query "Images[0].ImageId" \
    --output text)

echo "   AMI Linux   : $AMI_LINUX_ID"
echo "   AMI Windows : $AMI_WINDOWS_ID"

# 3. Copiar las AMIs hacia Oregon
echo "-- Copiando imagenes a $DR_REGION..."

aws ec2 copy-image \
    --source-region "$ORIGEN_REGION" \
    --source-image-id "$AMI_LINUX_ID" \
    --region "$DR_REGION" \
    --name "DR-MoscoRetail-Linux-AMI" \
    --description "Copia DR - Linux"

aws ec2 copy-image \
    --source-region "$ORIGEN_REGION" \
    --source-image-id "$AMI_WINDOWS_ID" \
    --region "$DR_REGION" \
    --name "DR-MoscoRetail-Windows-AMI" \
    --description "Copia DR - Windows"

echo "========================================================================="
echo " Proceso enviado. La VPC y las AMIs se estan replicando en Oregon."
echo "========================================================================="
