# Apache Geode How-To




TODO - Steps to create server/client certificate

## Intermediate CA
```
# cd /root/ca/intermediate
# touch index.txt.attr
```

## GemFire Server Certificates
```
# cd /root/ca
# openssl genrsa -aes256 \
      -out intermediate/private/locator1.example.com.key.pem 2048
# chmod 400 intermediate/private/locator1.example.com.key.pem
```

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

```
# cd /root/ca
# openssl ca -config intermediate/openssl.cnf \
      -extensions server_client_cert -days 375 -notext -md sha256 \
      -in intermediate/csr/locator1.example.com.csr.pem \
      -out intermediate/certs/locator1.example.com.cert.pem
# chmod 444 intermediate/certs/locator1.example.com.cert.pem
```


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

