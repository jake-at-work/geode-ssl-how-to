# Apache Geode SSL How-To

Follow Jamie Nguyen's [OpenSSL Certificate Authority](https://jamielinux.com/docs/openssl-certificate-authority/index.html) and stop after completing the *Create the intermediate pair* section.

---
## Root CA

---
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
# keytool -importcert -file certs/intermediate.cert.pem \
      -alias "Example Intermediate CA" \
      -keystore keystore/truststore.jks
# chmod 444 keystore/truststore.jks
```

---
## Geode Server and Locator Certificates
Creating a certificate for a server is exactly the same as for the locator. It is best practice that your certificate file name and Common Name (CN) match the hostname of the server. If you have multiple servers running on the same host then use the same key and certificate for each server on that host. If you have a locator sharing the same host as the server then the locator should use that same key and certificate as well. If you have more than one host, for example locator1, server1, server2, then repeat these steps for each hostname.

Generate a private key for *server.example.com*. Replace *server.example.com* with the server and locator hostnames.
```
# cd /root/ca
# openssl genrsa -aes256 \
      -out intermediate/private/server.example.com.key.pem 2048
# chmod 400 intermediate/private/server.example.com.key.pem
```

Generate a certificate signing request (CSR) for using the private key we just created. Be sure to set the **Common Name** to the hostname of the server.
```
# cd /root/ca
# openssl req -config intermediate/openssl.cnf \
      -key intermediate/private/server.example.com.key.pem \
      -new -sha256 -out intermediate/csr/server.example.com.csr.pem

Enter pass phrase for server.example.com.key.pem:
You are about to be asked to enter information that will be incorporated
into your certificate request.
-----
Country Name (2 letter code) [XX]:US
State or Province Name []:California
Locality Name []:Mountain View
Organization Name []:Alice Ltd
Organizational Unit Name []:Alice Ltd Web Services
Common Name []:server.example.com
Email Address []:
```

Use the intermediate CA to create a certificate that will work for both server and client authentication. Since servers and locators act as peers in the distributed system they are as both client and server in terms of SSL/TLS. To do this we use the `geode_server_cert` extenstion defined in the `intermediate/openssl.cnf` file.
```
# cd /root/ca
# openssl ca -config intermediate/openssl.cnf \
      -extensions geode_server_cert -days 375 -notext -md sha256 \
      -in intermediate/csr/server.example.com.csr.pem \
      -out intermediate/certs/server.example.com.cert.pem
# chmod 444 intermediate/certs/server.example.com.cert.pem
```
Create Java keystore in PKCS#12 format.
```
# cd /root/ca
# openssl pkcs12 -export -chain -CAfile intermediate/certs/ca-chain.cert.pem \
      -inkey intermediate/private/server.example.com.key.pem \
      -in intermediate/certs/server.example.com.cert.pem \
      -name server.example.com \
      -out intermediate/keystore/server.example.com.keystore.p12
# chmod 444 intermediate/keystore/server.example.com.keystore.p12
```
Optionally convert to JKS format for Geode older than 1.2.
```
# cd /root/ca
# keytool -importkeystore -srcstoretype pkcs12 \
      -srckeystore intermediate/keystore/server.example.com.keystore.p12 \
      -destkeystore intermediate/keystore/server.example.com.keystore.jks
# chmod 444 intermediate/keystore/server.example.com.keystore.jks
```

---
## Geode Client Certificates
Client certificate authentication is option in Geode. The server only validates the chain of trust in the client certificate. The server does not validate any of the attributes in the certificate. It is bad practice to share private keys across multiple hosts since you would have to re-key and certificate all your hosts should the shared key become compromised. It is suggested that you at least create a client certificate per host running client processes. You may create mulitple client certificates per host. The following instructions assume a single client certificate per host. Repeat this process for each client host that will connect to the Geode cache cluster.

Generate a private key for *client.example.com*. Replace *client.example.com* with your client hostnames.
```
# cd /root/ca
# openssl genrsa -aes256 \
      -out intermediate/private/client.example.com.key.pem 2048
# chmod 400 intermediate/private/client.example.com.key.pem
```

Generate a certificate signing request for using the private key we just created.
```
# cd /root/ca
# openssl req -config intermediate/openssl.cnf \
      -key intermediate/private/client.example.com.key.pem \
      -new -sha256 -out intermediate/csr/client.example.com.csr.pem

Enter pass phrase for client.example.com.key.pem:
You are about to be asked to enter information that will be incorporated
into your certificate request.
-----
Country Name (2 letter code) [XX]:US
State or Province Name []:California
Locality Name []:Mountain View
Organization Name []:Alice Ltd
Organizational Unit Name []:Alice Ltd Web Services
Common Name []:client.example.com
Email Address []:
```

Use the intermediate CA to create a certificate that will work for client authentication only using the `geode_client_cert` extenstion defined in the `intermediate/openssl.cnf` file.
```
# cd /root/ca
# openssl ca -config intermediate/openssl.cnf \
      -extensions geode_client_cert -days 375 -notext -md sha256 \
      -in intermediate/csr/client.example.com.csr.pem \
      -out intermediate/certs/client.example.com.cert.pem
# chmod 444 intermediate/certs/client.example.com.cert.pem
```

### Java Clients
Create Java keystore in PKCS#12 format.
```
# cd /root/ca
# openssl pkcs12 -export -chain -CAfile intermediate/certs/ca-chain.cert.pem \
      -inkey intermediate/private/client.example.com.key.pem \
      -in intermediate/certs/client.example.com.cert.pem \
      -name client.example.com \
      -out intermediate/keystore/client.example.com.keystore.p12
# chmod 444 intermediate/keystore/client.example.com.keystore.p12
```
Optionally convert to JKS format for Geode older than 1.2.
```
# cd /root/ca
# keytool -importkeystore -srcstoretype pkcs12 \
      -srckeystore intermediate/keystore/client.example.com.keystore.p12 \
      -destkeystore intermediate/keystore/client.example.com.keystore.jks
# chmod 444 intermediate/keystore/client.example.com.keystore.jks
```

### Native Clients
Create a keystore PEM file. Note that the private key must be first in the file.
```
# cd /root/ca
# cat intermediate/private/client.example.com.key.pem \
      intermediate/certs/client.example.com.cert.pem \
      > intermediate/keystore/client.example.com.keystore.pem
# chmod 444 intermediate/keystore/client.example.com.keystore.pem
```

---
## Deployment
### Locator
Make locator runtime directory.
```
# mdkir -p ~/geode/locator1
```

Securely copy the keystore and truststore to locators.
```
# cd /root/ca
# scp intermediate/keystore/locator1.example.com.keystore.jks \
      intermediate/keystore/truststore.jks \
      locator1.example.com:geode/locator1
```

Add to `~/geode/locator1/security.properties`
```
ssl-enabled-components=all
ssl-keystore=locator1.example.com.keystore.jks
ssl-keystore-password=secretpassword
ssl-keystore-type=jks
ssl-truststore=truststore.jks
ssl-truststore-password=secretpassword
```

Start the locator.
```
# cd ~/geode
# gfsh
gfsh>start locator --name=locator1 --security-properties-file=locator1/security.properties
```

### Server
Make server runtime directory.
```
# mdkir -p ~/geode/server1
```

Securely copy the keystore and truststore to locators.
```
# cd /root/ca
# scp intermediate/keystore/server1.example.com.keystore.jks \
      intermediate/keystore/truststore.jks \
      server1.example.com:geode/server1
```

Add to `~/geode/server1/security.properties`
```
ssl-enabled-components=all
ssl-keystore=server1.example.com.keystore.jks
ssl-keystore-password=secretpassword
ssl-keystore-type=jks
ssl-truststore=truststore.jks
ssl-truststore-password=secretpassword
```

Start the server.
```
# cd ~/geode
# gfsh
gfsh>start server --name=server1 --security-properties-file=server1/security.properties
```

### Java Client

### Native Client

---
## Cheat
Use the provided `newcert.sh` script to automate the server and client certificate creation.
```
# ./newcert.sh
USAGE: ../geode-ssl-how-to/newcert.sh <server|client> [hostname]
```

### Server
```
# cd /root/ca
# ./newcert.sh server server.example.com

...
     Private Key: intermediate/private/server.example.com.key.pem
     Certificate: intermediate/certs/server.example.com.cert.pem
Keystore PKCS#12: intermediate/keystore/server.example.com.keystore.p12
    Keystore JKS: intermediate/keystore/server.example.com.keystore.jks
    Keystore PEM: intermediate/keystore/server.example.com.keystore.pem
```

### Client
```
# cd /root/ca
# ./newcert.sh client client.example.com

...
     Private Key: intermediate/private/client.example.com.key.pem
     Certificate: intermediate/certs/client.example.com.cert.pem
Keystore PKCS#12: intermediate/keystore/client.example.com.keystore.p12
    Keystore JKS: intermediate/keystore/client.example.com.keystore.jks
    Keystore PEM: intermediate/keystore/client.example.com.keystore.pem
```
