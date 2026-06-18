#!/bin/bash

REGION="us-east-1"
INSTANCE_TYPE="t3.small"
export AWS_PAGER=""

ARCHIVO_PEM="MoscoRetail.pem"
KEY_NAME="mi-llave-moscoretail"

echo "--- Importando llave de acceso ---"

if [ ! -f "$ARCHIVO_PEM" ]; then
    echo "Error: no se encuentra el archivo $ARCHIVO_PEM."
    exit 1
fi

ssh-keygen -y -f "$ARCHIVO_PEM" > temporal_publica.pub 2>/dev/null
aws ec2 import-key-pair \
    --region "$REGION" \
    --key-name "$KEY_NAME" \
    --public-key-material fileb://temporal_publica.pub 2>/dev/null
rm -f temporal_publica.pub

echo "--- Obteniendo datos de red ---"

VPC_ID=$(aws cloudformation describe-stacks \
    --stack-name vpc-MoscoRetail \
    --region "$REGION" \
    --query "Stacks[0].Outputs[?ExportName=='vpc-moscoretail-id'].OutputValue" \
    --output text)

SUBNET_WEB=$(aws cloudformation describe-stacks \
    --stack-name vpc-MoscoRetail \
    --region "$REGION" \
    --query "Stacks[0].Outputs[?ExportName=='subnet-publica-web-id'].OutputValue" \
    --output text)

SUBNET_APP=$(aws cloudformation describe-stacks \
    --stack-name vpc-MoscoRetail \
    --region "$REGION" \
    --query "Stacks[0].Outputs[?ExportName=='subnet-publica-app-id'].OutputValue" \
    --output text)

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    echo "Error: no se pudo obtener la VPC. Revisa que el stack este creado."
    exit 1
fi

echo "--- Creando Security Group ---"

SG_INSTANCIAS=$(aws ec2 create-security-group \
    --group-name "SG-Web-MoscoRetail" \
    --description "Security Group para Servidores Web MoscoRetail" \
    --vpc-id "$VPC_ID" \
    --region "$REGION" \
    --query "GroupId" --output text)

echo "Security Group: $SG_INSTANCIAS"

echo "--- Generando user data ---"

cat << 'EOF' > userdata_linux.sh
#!/bin/bash
dnf update -y
dnf install -y git httpd
systemctl start httpd
systemctl enable httpd
git clone https://github.com/ByteKnight-glitch/MoscoRetail.git /tmp/MoscoRetail
cp /tmp/MoscoRetail/index1.html /var/www/html/index.html
EOF

cat << 'EOF' > userdata_windows.txt
<powershell>
Install-WindowsFeature -name Web-Server -IncludeManagementTools
Invoke-WebRequest `
-Uri "https://raw.githubusercontent.com/ByteKnight-glitch/MoscoRetail/main/index2.html" `
-OutFile "C:\inetpub\wwwroot\index.html"
iisreset
</powershell>
EOF

echo "--- Lanzando instancias EC2 ---"

AMI_LINUX="ami-0521cb2d60cfbb1a6"
AMI_WINDOWS="ami-09639480113b0df96"

echo "Lanzando servidor Linux..."
aws ec2 run-instances \
    --region "$REGION" \
    --image-id "$AMI_LINUX" \
    --instance-type "$INSTANCE_TYPE" \
    --subnet-id "$SUBNET_WEB" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_INSTANCIAS" \
    --user-data file://userdata_linux.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MoscoRetail-Linux-Server}]'

echo "Lanzando servidor Windows..."
aws ec2 run-instances \
    --region "$REGION" \
    --image-id "$AMI_WINDOWS" \
    --instance-type "$INSTANCE_TYPE" \
    --subnet-id "$SUBNET_APP" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_INSTANCIAS" \
    --user-data file://userdata_windows.txt \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MoscoRetail-Windows-Server}]'

rm -f userdata_linux.sh userdata_windows.txt

echo "Listo. Instancias en proceso de inicio."
