#!/bin/bash
REGION="us-east-1"
export AWS_PAGER=""

echo "--- Configurando Balanceador de Carga ---"

# Recuperar IDs de red e instancias
VPC_ID=$(aws cloudformation describe-stacks --stack-name vpc-MoscoRetail --region $REGION --query "Stacks[0].Outputs[?ExportName=='vpc-moscoretail-id'].OutputValue" --output text)
SUBNET_WEB=$(aws cloudformation describe-stacks --stack-name vpc-MoscoRetail --region $REGION --query "Stacks[0].Outputs[?ExportName=='subnet-publica-web-id'].OutputValue" --output text)
SUBNET_APP=$(aws cloudformation describe-stacks --stack-name vpc-MoscoRetail --region $REGION --query "Stacks[0].Outputs[?ExportName=='subnet-publica-app-id'].OutputValue" --output text)
INSTANCE_LINUX=$(aws ec2 describe-instances --region $REGION --filters "Name=tag:Name,Values=MoscoRetail-Linux-Server" "Name=instance-state-name,Values=running,pending" --query "Reservations[0].Instances[0].InstanceId" --output text)
INSTANCE_WINDOWS=$(aws ec2 describe-instances --region $REGION --filters "Name=tag:Name,Values=MoscoRetail-Windows-Server" "Name=instance-state-name,Values=running,pending" --query "Reservations[0].Instances[0].InstanceId" --output text)

# Security Group para el ALB
echo "Creando Security Group para el ALB..."
SG_ALB=$(aws ec2 create-security-group --group-name "SG-ALB-MoscoRetail" --description "Security Group para ALB" --vpc-id "$VPC_ID" --region $REGION --query "GroupId" --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_ALB" --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION


SG_INSTANCIAS=$(aws ec2 describe-security-groups \
    --region $REGION \
    --filters "Name=group-name,Values=SG-Web-MoscoRetail" \
    --query "SecurityGroups[0].GroupId" --output text)

aws ec2 authorize-security-group-ingress \
    --group-id "$SG_INSTANCIAS" \
    --protocol tcp \
    --port 80 \
    --source-group "$SG_ALB" \
    --region $REGION

# Target Group
echo "Creando Target Group..."
TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
    --name "TG-MoscoRetail" \
    --protocol HTTP \
    --port 80 \
    --vpc-id "$VPC_ID" \
    --region $REGION \
    --query "TargetGroups[0].TargetGroupArn" --output text)

# Registrar instancias
echo "Registrando instancias en el Target Group..."
aws elbv2 register-targets \
    --target-group-arn "$TARGET_GROUP_ARN" \
    --targets Id="$INSTANCE_LINUX" Id="$INSTANCE_WINDOWS" \
    --region $REGION

# Crear ALB
echo "Creando Application Load Balancer..."
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name "ALB-MoscoRetail" \
    --subnets "$SUBNET_WEB" "$SUBNET_APP" \
    --security-groups "$SG_ALB" \
    --region $REGION \
    --query "LoadBalancers[0].LoadBalancerArn" --output text)

# Listener puerto 80
echo "Configurando Listener..."
aws elbv2 create-listener \
    --load-balancer-arn "$ALB_ARN" \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn="$TARGET_GROUP_ARN" \
    --region $REGION

echo "Listo. ALB configurado."
