# Apache Geode SSL How-To

Follow Jamie Nguyen's [OpenSSL Certificate Authority](https://jamielinux.com/docs/openssl-certificate-authority/index.html) and stop after completing the *Create the intermediate pair* section.

## Root CA

## Intermediate CA
Add the following extensions to the `/roo/ca/intermediate/openssl.cnf` file you created.
```
[ geode_server_cert ]
# Extensions for server/client certificates (`man x509v3_config`).
basicConstraints = CA:FALSE
nsCertType = server, client
nsComment = "OpenSSL Generated Geode Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth

[ geode_client_cert ]
# Extensions for server/client certificates (`man x509v3_config`).
basicConstraints = CA:FALSE
nsCertType = client
nsComment = "OpenSSL Generated Geode Client Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
```

Create directory for keystores.
```
# cd /root/ca/intermediate
# mkdir keystore
```

This step appears neccessary on some versions of OpenSSL.
```
# cd /root/ca/intermediate
# touch index.txt.attr
```

Create a Java compatible truststore. While normally you should only need to trust the root CA, due to a limitation of Geode Native you must trust all intermediate CAs as well.
```
# cd /root/ca/intermediate
# keytool -importcert -file ../certs/ca.cert.pem \
      -alias "Example Root CA" \
      -keystore keystore/truststore.jks

Enter keystore password:  secretpassword

# keytool -importcert -file certs/intermediate.cert.pem \
      -alias "Example Intermediate CA" \
      -keystore keystore/truststore.jks

Enter keystore password:  secretpassword

# chmod 444 keystore/truststore.jks
```

---
## Geode Server Certificates
### Locator
It is best practice that your certificate file name and Common Name (CN) match the hostname of the locator. If you have more than one locator then repeat these steps for each locator.

Generate a private key for *locator1.example.com*.
```
# cd /root/ca
# openssl genrsa -aes256 \
      -out intermediate/private/locator1.example.com.key.pem 2048
# chmod 400 intermediate/private/locator1.example.com.key.pem
```

Generate a certificate signing request for using the private key we just created. Be sure to set the **Common Name** to the hostname of the locator.
```
# cd /root/ca
# openssl req -config intermediate/openssl.cnf \
      -key intermediate/private/locator1.example.com.key.pem \
      -new -sha256 -out intermediate/csr/locator1.example.com.csr.pem

Enter pass phrase for locator1.example.com.key.pem: secretpassword
You are about to be asked to enter information that will be incorporated
into your certificate request.
-----
Country Name (2 letter code) [XX]:US
State or Province Name []:California
Locality Name []:Mountain View
Organization Name []:Alice Ltd
Organizational Unit Name []:Alice Ltd Web Services
Common Name []:locator1.example.com
Email Address []:
```

Use the intermediate CA to create a certificate that will work for both server and client authentication. Because locators act as peers in the distributed system they are as both client and server in terms of SSL/TLS. To do this we use the `server_client_cert` extenstion we defined in the `intermediate/openssl.cnf` file.
```
# cd /root/ca
# openssl ca -config intermediate/openssl.cnf \
      -extensions server_client_cert -days 375 -notext -md sha256 \
      -in intermediate/csr/locator1.example.com.csr.pem \
      -out intermediate/certs/locator1.example.com.cert.pem
# chmod 444 intermediate/certs/locator1.example.com.cert.pem
```

### Geode Server
Creating a certificate for a server is exactly the same as you did for the locator except for changing the hostname. It is best practice that your certificate file name and Common Name (CN) match the hostname of the server. If you have more than one server then repeat these steps for each server. If you have multiple servers running on the same host then use the same key and certificate for each server on that host. If you have a locator sharing the same host as the server then the locator should use that same key and certificate as well.

Generate a private key for *server1.example.com*.
```
# cd /root/ca
# openssl genrsa -aes256 \
      -out intermediate/private/server1.example.com.key.pem 2048
# chmod 400 intermediate/private/server1.example.com.key.pem
```

Generate a certificate signing request for using the private key we just created. Be sure to set the **Common Name** to the hostname of the server.
```
# cd /root/ca
# openssl req -config intermediate/openssl.cnf \
      -key intermediate/private/server1.example.com.key.pem \
      -new -sha256 -out intermediate/csr/server1.example.com.csr.pem

Enter pass phrase for server1.example.com.key.pem: secretpassword
You are about to be asked to enter information that will be incorporated
into your certificate request.
-----
Country Name (2 letter code) [XX]:US
State or Province Name []:California
Locality Name []:Mountain View
Organization Name []:Alice Ltd
Organizational Unit Name []:Alice Ltd Web Services
Common Name []:server1.example.com
Email Address []:
```

Use the intermediate CA to create a certificate that will work for both server and client authentication. Since servers act as peers in the distributed system they are as both client and server in terms of SSL/TLS. To do this we use the `geode_server_cert` extenstion defined in the `intermediate/openssl.cnf` file.
```
# cd /root/ca
# openssl ca -config intermediate/openssl.cnf \
      -extensions geode_server_cert -days 375 -notext -md sha256 \
      -in intermediate/csr/server1.example.com.csr.pem \
      -out intermediate/certs/server1.example.com.cert.pem
# chmod 444 intermediate/certs/server1.example.com.cert.pem
```

Create Java keystore. If you are using Geode 1.2+ you can stop at the PKCS#12 formatted keystore statement.
```
# cd /root/ca
# cat intermediate/certs/server1.example.com.cert.pem \
      intermediate/certs/ca-chain.cert.pem \
      > intermediate/certs/server1.example.com.chain.pem
# chmod 444 intermediate/certs/server1.example.com.chain.pem
```
```
# openssl pkcs12 -export \
      -inkey intermediate/private/server1.example.com.key.pem \
      -in intermediate/certs/server1.example.com.cert.pem \
      -in intermediate/certs/ca-chain.cert.pem \
      -name server1.example.com \
      -out intermediate/keystore/server1.example.com.keystore.p12
# chmod 444 intermediate/keystore/server1.example.com.keystore.p12
```
Convert to JKS format for Geode older than 1.2.
```
# keytool -importkeystore \
      -srckeystore intermediate/keystore/server1.example.com.keystore.p12 \
      -srcstoretype pkcs12 \
      -destkeystore intermediate/keystore/server1.example.com.keystore.jks
# chmod 444 intermediate/keystore/server1.example.com.keystore.jks
```

---

## Geode Clients Certificates
Client certificate authentication is option in Geode. The server only validates the chain of trust in the client certifacate. The server does not validate any of the attributes in the certificate. It is bad practice to share private keys across multiple hosts since you would have to re-key and certificate all your hosts should the shared key become compromised. It is suggested that you at least create a client certificate per host running client processes. You may create mulitple client certificates per host. The following instructions assume a single client certificate per host. Repeat this process for each client host that will connect to the Geode cache cluster.

Generate a private key for *client1.example.com*.
```
# cd /root/ca
# openssl genrsa -aes256 \
      -out intermediate/private/client1.example.com.key.pem 2048
# chmod 400 intermediate/private/client1.example.com.key.pem
```

Generate a certificate signing request for using the private key we just created.
```
# cd /root/ca
# openssl req -config intermediate/openssl.cnf \
      -key intermediate/private/client1.example.com.key.pem \
      -new -sha256 -out intermediate/csr/client1.example.com.csr.pem

Enter pass phrase for client1.example.com.key.pem: secretpassword
You are about to be asked to enter information that will be incorporated
into your certificate request.
-----
Country Name (2 letter code) [XX]:US
State or Province Name []:California
Locality Name []:Mountain View
Organization Name []:Alice Ltd
Organizational Unit Name []:Alice Ltd Web Services
Common Name []:client1.example.com
Email Address []:
```

Use the intermediate CA to create a certificate that will work for client authentication only using the `geode_client_cert` extenstion defined in the `intermediate/openssl.cnf` file.
```
# cd /root/ca
# openssl ca -config intermediate/openssl.cnf \
      -extensions geode_client_cert -days 375 -notext -md sha256 \
      -in intermediate/csr/client1.example.com.csr.pem \
      -out intermediate/certs/client1.example.com.cert.pem
# chmod 444 intermediate/certs/client1.example.com.cert.pem
```

### Java Clients
*TODO Java keytool*

### Native Clients
Create a keystore PEM file. Note that the private key must be first in the file.
```
# cd /root/ca
# cat intermediate/private/client1.example.com.key.pem \
      intermediate/certs/client1.example.com.cert.pem \
      > intermediate/keystore/client1.example.com.keystore.pem
# chmod 444 intermediate/keystore/client1.example.com.keystore.pem
```

---
## Deployment
