# Apache Geode How-To

Follow Jamie Nguyen's (OpenSSL Certificate Authority)[https://jamielinux.com/docs/openssl-certificate-authority/index.html] guide with the below ammendments.


## Intermediate CA
Add the following extension to the `/roo/ca/intermediate/openssl.cnf` file you created.
```
[ server_client_cert ]
# Extensions for server/client certificates (`man x509v3_config`).
basicConstraints = CA:FALSE
nsCertType = server, client
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
```

This step appears neccessary on some versions of OpenSSL.
```
# cd /root/ca/intermediate
# touch index.txt.attr
```

## GemFire Server Certificates
### Locator
It is best practice that your certificate file name and Common Name (CN) match the hostname of the locator. If you have more than one locator then repeat these steps for each locator.

Generate a private key for locator1.example.com.
```
# cd /root/ca
# openssl genrsa -aes256 \
      -out intermediate/private/locator1.example.com.key.pem 2048
# chmod 400 intermediate/private/locator1.example.com.key.pem
```

Generate a certificate signing request for using the private key we just created.
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

Use oure intermediate CA to create a certificate that will work for both server and client authentication. Because locators act as peers in the distributed system they act as both client and server in terms of SSL/TLS. To do this we use the `server_client_cert` extenstion we defined in the `intermediate/openssl.cnf` file.
```
# cd /root/ca
# openssl ca -config intermediate/openssl.cnf \
      -extensions server_client_cert -days 375 -notext -md sha256 \
      -in intermediate/csr/locator1.example.com.csr.pem \
      -out intermediate/certs/locator1.example.com.cert.pem
# chmod 444 intermediate/certs/locator1.example.com.cert.pem
```

### Server
Creating a certificate for a server is exactly the same as you did for the locator except for changing the hostname. It is best practice that your certificate file name and Common Name (CN) match the hostname of the server. If you have more than one server then repeat these steps for each server. If you have multiple servers running on the same host then use the same key and certificate for each server on that host. If you have a locator sharing the same host as the server then the locator should use that same key and certificate as well. 

```
# cd /root/ca
# openssl genrsa -aes256 \
      -out intermediate/private/server1.example.com.key.pem 2048
# chmod 400 intermediate/private/server1.example.com.key.pem
```

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
```
# cd /root/ca
# openssl ca -config intermediate/openssl.cnf \
      -extensions server_client_cert -days 375 -notext -md sha256 \
      -in intermediate/csr/server1.example.com.csr.pem \
      -out intermediate/certs/server1.example.com.cert.pem
# chmod 444 intermediate/certs/server1.example.com.cert.pem
```

