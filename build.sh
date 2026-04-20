#!/bin/bash
set -euo pipefail

APP_NAME="SnapMark"
BUILD_DIR=".build/release"
OUTPUT_DIR="dist"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"

SIGNING_DIR="${HOME}/.snapmark-signing"
KEYCHAIN_PATH="${HOME}/Library/Keychains/snapmark-build.keychain-db"
KEYCHAIN_PASSWORD="snapmark-build"
IDENTITY_NAME="SnapMark Local Development"
P12_PATH="${SIGNING_DIR}/snapmark-local-development.p12"
P12_PASSWORD="snapmark-local-development"

resolve_identity_hash() {
	security find-certificate -Z -a -c "${IDENTITY_NAME}" "${KEYCHAIN_PATH}" 2>/dev/null \
		| awk '/SHA-1 hash:/ { print $3; exit }'
}

ensure_signing_identity() {
	mkdir -p "${SIGNING_DIR}"

	if [[ ! -f "${KEYCHAIN_PATH}" ]]; then
		security create-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
		security set-keychain-settings -lut 21600 "${KEYCHAIN_PATH}"
	fi

	security unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"

	if [[ -z "$(resolve_identity_hash)" ]]; then
		local tmpdir
		tmpdir="$(mktemp -d)"

		cat > "${tmpdir}/openssl.cnf" <<'EOF'
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no

[dn]
CN = SnapMark Local Development

[v3]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

		openssl req -x509 -newkey rsa:2048 -nodes \
			-keyout "${tmpdir}/signing.key" \
			-out "${tmpdir}/signing.crt" \
			-days 3650 \
			-config "${tmpdir}/openssl.cnf"

		openssl pkcs12 -export \
			-legacy \
			-inkey "${tmpdir}/signing.key" \
			-in "${tmpdir}/signing.crt" \
			-out "${P12_PATH}" \
			-name "${IDENTITY_NAME}" \
			-keypbe PBE-SHA1-3DES \
			-certpbe PBE-SHA1-3DES \
			-macalg sha1 \
			-passout pass:"${P12_PASSWORD}"

		security import "${P12_PATH}" \
			-k "${KEYCHAIN_PATH}" \
			-P "${P12_PASSWORD}" \
			-T /usr/bin/codesign \
			-T /usr/bin/security >/dev/null

		security set-key-partition-list \
			-S apple-tool:,apple:,codesign: \
			-s \
			-k "${KEYCHAIN_PASSWORD}" \
			"${KEYCHAIN_PATH}" >/dev/null

		rm -rf "${tmpdir}"
	fi

	local existing_keychains
	existing_keychains="$(security list-keychains -d user | tr -d '"')"
	if ! printf '%s\n' "${existing_keychains}" | grep -Fxq "${KEYCHAIN_PATH}"; then
		security list-keychains -d user -s "${KEYCHAIN_PATH}" ${existing_keychains}
	fi
}

echo "🔨 Building ${APP_NAME}..."
swift build -c release

ensure_signing_identity

echo "📦 Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}"
mkdir -p "${CONTENTS}/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${MACOS}/${APP_NAME}"
cp Info.plist "${CONTENTS}/Info.plist"

IDENTITY_HASH="$(resolve_identity_hash)"
if [[ -z "${IDENTITY_HASH}" ]]; then
	echo "Failed to resolve SnapMark signing certificate hash" >&2
	exit 1
fi

codesign --force --deep --keychain "${KEYCHAIN_PATH}" --sign "${IDENTITY_HASH}" --identifier com.snapmark.app "${APP_BUNDLE}"

echo "✅ Built ${APP_BUNDLE}"
echo ""
echo "To run:"
echo "  open ${APP_BUNDLE}"
echo ""
echo "To install:"
echo "  cp -r ${APP_BUNDLE} /Applications/"
echo ""
echo "Note: On first run, macOS will prompt for Screen Recording permission."
echo "Grant it in System Settings > Privacy & Security > Screen Recording."
