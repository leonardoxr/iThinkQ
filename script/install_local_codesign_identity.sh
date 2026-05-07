#!/usr/bin/env bash
set -euo pipefail

IDENTITY_NAME="${THINKQ_LOCAL_SIGN_IDENTITY:-ThinkQ Local Development}"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
P12_PASSWORD="$(/usr/bin/openssl rand -hex 24)"

if /usr/bin/security find-certificate -c "$IDENTITY_NAME" "$KEYCHAIN" >/dev/null 2>&1; then
  echo "Code-signing identity already exists: $IDENTITY_NAME"
  exit 0
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

OPENSSL_CONFIG="$WORK_DIR/codesign.cnf"
KEY_PATH="$WORK_DIR/codesign.key"
CERT_PATH="$WORK_DIR/codesign.crt"
P12_PATH="$WORK_DIR/codesign.p12"

cat >"$OPENSSL_CONFIG" <<EOF
[ req ]
distinguished_name = req_distinguished_name
x509_extensions = codesign_ext
prompt = no

[ req_distinguished_name ]
CN = $IDENTITY_NAME
O = ThinkQ

[ codesign_ext ]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = codeSigning
subjectKeyIdentifier = hash
EOF

/usr/bin/openssl req \
  -newkey rsa:2048 \
  -nodes \
  -x509 \
  -days 3650 \
  -config "$OPENSSL_CONFIG" \
  -keyout "$KEY_PATH" \
  -out "$CERT_PATH" >/dev/null 2>&1

/usr/bin/openssl pkcs12 \
  -export \
  -inkey "$KEY_PATH" \
  -in "$CERT_PATH" \
  -out "$P12_PATH" \
  -passout "pass:$P12_PASSWORD" >/dev/null 2>&1

/usr/bin/security import "$P12_PATH" \
  -k "$KEYCHAIN" \
  -P "$P12_PASSWORD" \
  -T /usr/bin/codesign >/dev/null

echo "Installed local code-signing identity: $IDENTITY_NAME"
echo "Future script/build_and_run.sh launches will sign ThinkQ with this stable identity."
