# g2rain-knowledge-app OpenResty keys

Runtime mount: `./config/g2rain-knowledge-app/keys` → `/usr/local/openresty/nginx/lua/keys`.

Required:

- `private-key.der` / `public-key.der` — Application-DPoP signing
- `iam-key-id.txt` — IAM kid
- `iam-public-key.pem` — IAM public key for JWT verify

`public-key.pem` is kept for Basis `application.public_key` registration (`application_code=g2rain-knowledge-app`, `context_path=/knowledge/`).

```shell
./config/generate_key.sh config/g2rain-knowledge-app/keys
```

Demo material only. Do not reuse in production.
