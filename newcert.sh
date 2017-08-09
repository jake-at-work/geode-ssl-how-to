#!/usr/bin/env bash -e

type=$1
host=$2

if [ -z "${host}" ] || [ -z "${type}"]; then
  echo "USAGE: $0 <server|client> [hostname]"
  exit 1
fi

echo "Generate a private key for ${host}."
openssl genrsa -aes256 \
      -out intermediate/private/${host}.key.pem 2048
chmod 400 intermediate/private/${host}.key.pem

echo "Generate a certificate signing request (CSR)."
openssl req -config intermediate/openssl.cnf \
      -key intermediate/private/${host}.key.pem \
      -new -sha256 -out intermediate/csr/${host}.csr.pem

echo "Signing server certificate with intermediate."
openssl ca -config intermediate/openssl.cnf \
            -extensions geode_${type}_cert -days 375 -notext -md sha256 \
            -in intermediate/csr/${host}.csr.pem \
            -out intermediate/certs/${host}.cert.pem
chmod 444 intermediate/certs/${host}.cert.pem

echo "Create Java keystore in PKCS#12 format."
openssl pkcs12 -export -chain -CAfile intermediate/certs/ca-chain.cert.pem \
      -inkey intermediate/private/${host}.key.pem \
      -in intermediate/certs/${host}.cert.pem \
      -name ${host} \
      -out intermediate/keystore/${host}.keystore.p12
chmod 444 intermediate/keystore/${host}.keystore.p12

echo "Create Java keystore in JKS format."
keytool -importkeystore -srcstoretype pkcs12 \
      -srckeystore intermediate/keystore/${host}.keystore.p12 \
      -destkeystore intermediate/keystore/${host}.keystore.jks
chmod 444 intermediate/keystore/${host}.keystore.jks

if [ "${type}" = "client" ]; then
  echo "Create Native keystore in PEM format."
  cat intermediate/private/${host}.key.pem \
        intermediate/certs/${host}.cert.pem \
        > intermediate/keystore/${host}.keystore.pem
  chmod 444 intermediate/keystore/${host}.keystore.pem
fi

echo "     Private Key: intermediate/private/${host}.key.pem"
echo "     Certificate: intermediate/certs/${host}.cert.pem"
echo "Keystore PKCS#12: intermediate/keystore/${host}.keystore.p12"
echo "    Keystore JKS: intermediate/keystore/${host}.keystore.jks"

if [ "${type}" = "client" ]; then
  echo "    Keystore PEM: intermediate/keystore/${host}.keystore.pem"
fi
