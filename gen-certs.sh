#!/usr/bin/env bash
set -e

script_dir=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
cert_dir="$script_dir/build/certs"

mkdir -p "$cert_dir"

function gen_cert {
    local common_name="$1"
    local ca_name="${2:-ca}"

    openssl genrsa -out ${cert_dir}/${common_name}_key.pem 2048 >/dev/null
    echo "Generated private key ${cert_dir}/${common_name}_key.pem"

    # Certificate signing request.
    openssl req -new -sha256 \
        -key ${cert_dir}/${common_name}_key.pem \
        -subj "/O=usockets/CN=${common_name}" \
        -reqexts SAN \
        -config <(cat /etc/ssl/openssl.cnf \
            <(printf "\n[SAN]\nsubjectAltName=DNS:localhost,DNS:127.0.0.1")) \
        -out ${cert_dir}/${common_name}.csr &>/dev/null

    if [ -z "$2" ]; then
        # Self-signed.
        openssl x509 -req -in ${cert_dir}/${common_name}.csr \
            -signkey ${cert_dir}/${common_name}_key.pem -days 3650 -sha256 \
            -outform PEM -out ${cert_dir}/${common_name}_crt.pem &>/dev/null
    else
        # Signed by certificate authority.
        openssl x509 -req -in ${cert_dir}/${common_name}.csr \
            -CA ${cert_dir}/${ca_name}_crt.pem -CAkey ${cert_dir}/${ca_name}_key.pem \
            -CAcreateserial -days 3650 -sha256 \
            -outform PEM -out ${cert_dir}/${common_name}_crt.pem &>/dev/null
    fi

    rm -f ${cert_dir}/${common_name}.csr
    echo "Generated certificate ${cert_dir}/${common_name}_crt.pem"
}

gen_cert "valid_ca"
gen_cert "valid_server" "valid_ca"
gen_cert "valid_client" "valid_ca"

gen_cert "invalid_ca"
gen_cert "invalid_client" "invalid_ca"
gen_cert "selfsigned_client"
