#!/usr/bin/env bash

RED='\033[0;31m';
GREEN='\033[0;32m';
YELLOW='\033[1;33m';
NC='\033[0m'; # No Color

if [ ! -f "myCa.key" ]; then
    echo -e "${YELLOW}Generating CA files${NC}"
    ######################
    # Become a Certificate Authority
    ######################

    # Generate private key
    openssl genrsa \
        -passout pass:secret \
        -des3 \
        -out myCA.key 2048
    # Generate root certificate
    openssl req \
        -x509 \
        -new \
        -nodes \
        -passin pass:secret \
        -key myCA.key \
        -sha256 \
        -days 825 \
        -subj "/C=UK/ST=Devon/L=Exeter/O=Reflow/CN=.reflow" \
        -out myCA.pem
        echo -e "${YELLOW}You'll need to trust the CA file${NC}"
fi

if [[ -z "$1" ]]; then
    echo -e "${RED}Please provide client directory${NC}";
    exit 1;
fi

######################
# Create CA-signed certs
######################

NAME=$1.reflow # Use your own domain name
# Generate a private key
openssl genrsa -out $NAME.key 2048
# Create a certificate-signing request
openssl req \
    -new \
    -key $NAME.key \
    -subj "/C=UK/ST=Devon/L=Exeter/O=Reflow/CN=$NAME.reflow" \
    -out $NAME.csr
# Create a config file for the extensions
>$NAME.ext cat <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
extendedKeyUsage=serverAuth,clientAuth
basicConstraints=CA:FALSE
[alt_names]
DNS.1 = $NAME # Be sure to include the domain name here because Common Name is not so commonly honoured by itself
DNS.2 = bar.$NAME # Optionally, add additional domains (I've added a subdomain here)
IP.1 = 192.168.0.13 # Optionally, add an IP address (if the connection which you have planned requires it)
EOF
# Create the signed certificate
openssl x509 \
    -req \
    -in $NAME.csr \
    -CA myCA.pem \
    -CAkey myCA.key \
    -CAcreateserial \
    -passin pass:secret \
    -out $NAME.crt \
    -days 825 \
    -sha256 \
    -extfile $NAME.ext

mv $NAME.crt certs
mv $NAME.key certs
rm $NAME.csr
rm $NAME.ext