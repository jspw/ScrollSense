#!/usr/bin/env bash
#
# Create a stable self-signed code-signing certificate for scrollSense.
#
# Why: ad-hoc signatures change on every rebuild, so macOS treats each build as
# a new app and forgets the Accessibility grant. Signing with a fixed identity
# keeps the binary's "designated requirement" stable, so you grant permission
# once and it survives every rebuild.
#
# Run this ONCE. Afterwards, ./install.sh signs with this identity automatically.
#
set -euo pipefail

CERT_NAME="ScrollSense Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
  echo "Signing identity '$CERT_NAME' already exists. Nothing to do."
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions    = v3
prompt             = no
[ dn ]
CN = $CERT_NAME
[ v3 ]
basicConstraints   = critical, CA:false
keyUsage           = critical, digitalSignature
extendedKeyUsage   = critical, codeSigning
EOF

echo "==> Generating self-signed code-signing certificate (valid 10 years)..."
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
  -days 3650 -config "$TMP/cert.cnf" >/dev/null 2>&1

openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -out "$TMP/cert.p12" -passout pass:scrollsense -name "$CERT_NAME" >/dev/null 2>&1

echo "==> Importing into your login keychain..."
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P scrollsense -T /usr/bin/codesign >/dev/null

echo "==> Trusting the certificate for code signing..."
echo "    (macOS will ask for your login password to update trust settings.)"
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem"

echo
if security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
  echo "Success — '$CERT_NAME' is ready."
  echo "Now run ./install.sh, then grant Accessibility ONCE. It will persist."
else
  echo "Hmm, the identity is not showing as valid yet."
  echo "Open Keychain Access and confirm '$CERT_NAME' is trusted for code signing."
fi
