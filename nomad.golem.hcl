recipe "nomad.setup-local" "local" {
    kv {
        path = "@golem.NOMAD_DC.nomad_encryption_key"
        value = "rand32"
    }
    artifact {
        template {
            data = <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h",
      "usages": ["signing", "key encipherment", "server auth", "client auth"]
    }
  }
}
            EOF
        }
        destination = "@golem.NOMAD_CONFIG_PATH/certs/cfssl.json"
    }
    script {
        commands = [
            // Install cfssl
            "go install github.com/cloudflare/cfssl/cmd/cfssl@latest",

            // Install cfssljson
            "go install github.com/cloudflare/cfssl/cmd/cfssljson@latest",

            // NOMAD_CONFIG_PATH/certs/nomad-ca-key.pem -> private key
            // NOMAD_CONFIG_PATH/certs/nomad-ca.csr -> certificate signing request
            // NOMAD_CONFIG_PATH/certs/nomad-ca.pem -> public key
            "cfssl print-defaults csr | cfssl gencert -initca - | cfssljson -bare @golem.NOMAD_CONFIG_PATH/certs/nomad-ca",
        ]
    }
    script {
        // server-key.pem -> private key
        // server.csr -> certificate signing request
        // server.pem -> public key
        command = <<EOF
echo '{}' | cfssl gencert -ca=@golem.NOMAD_CONFIG_PATH/certs/nomad-ca.pem -ca-key=@golem.NOMAD_CONFIG_PATH/certs/nomad-ca-key.pem -config=@golem.NOMAD_CONFIG_PATH/certs/cfssl.json -hostname="server.@golem.NOMAD_REGION.nomad,localhost,127.0.0.1,
{{- range $_, $s := (match "tags" "contains" "@golem.NOMAD_SERVER_TAG") -}}
    {{- if not ($s).PublicIP -}}
    {{- else -}}
        {{- ($s).PublicIP -}},
    {{- end -}}
    {{- if not ($s).PrivateIP -}}
    {{- else -}}
        {{- ($s).PrivateIP -}},
    {{- end -}}
{{- end -}}" - | cfssljson -bare @golem.NOMAD_CONFIG_PATH/certs/server
EOF
    }
    script {
        // client-key.pem -> private key
        // client.csr -> certificate signing request
        // client.pem -> public key
        command = <<EOF
echo '{}' | cfssl gencert -ca=@golem.NOMAD_CONFIG_PATH/certs/nomad-ca.pem -ca-key=@golem.NOMAD_CONFIG_PATH/certs/nomad-ca-key.pem -config=@golem.NOMAD_CONFIG_PATH/certs/cfssl.json -hostname="client.@golem.NOMAD_REGION.nomad,localhost,127.0.0.1,
{{- range $_, $s := (match "tags" "contains" "@golem.NOMAD_SERVER_TAG") -}}
    {{- if not ($s).PublicIP -}}
    {{- else -}}
        {{- ($s).PublicIP -}},
    {{- end -}}
    {{- if not ($s).PrivateIP -}}
    {{- else -}}
        {{- ($s).PrivateIP -}},
    {{- end -}}
{{ end }}" - | cfssljson -bare @golem.NOMAD_CONFIG_PATH/certs/client
EOF
    }
    script {
        commands = [
            "echo '{}' | cfssl gencert -ca=@golem.NOMAD_CONFIG_PATH/certs/nomad-ca.pem -ca-key=@golem.NOMAD_CONFIG_PATH/certs/nomad-ca-key.pem -profile=client - | cfssljson -bare @golem.NOMAD_CONFIG_PATH/certs/cli",
            "openssl rand 32 | base64 > @golem.NOMAD_CONFIG_PATH/certs/nomad.key",
        ]
    }
}

recipe "nomad.setup-remote" "remote" {
    match {
        attribute = "tags"
        operator = "contains"
        value = "@golem.NOMAD_SERVER_TAG"
    }
    artifact {
        template {
            path = "@golem.NOMAD_CONFIG_PATH/nomad_server.template.hcl"
        }
        destination = "/etc/nomad.d/nomad.hcl"
    }
    artifact {
        template {
            path = "@golem.NOMAD_CONFIG_PATH/certs/nomad-ca.pem"
        }
        destination = "/etc/nomad.d/nomad-ca.pem"
    }
    artifact {
        template {
            path = "@golem.NOMAD_CONFIG_PATH/certs/server.pem"
        }
        destination = "/etc/nomad.d/server.pem"
    }
    artifact {
        template {
            path = "@golem.NOMAD_CONFIG_PATH/certs/server-key.pem"
        }
        destination = "/etc/nomad.d/server-key.pem"
    }
    artifact {
        source = "@golem.NOMAD_CONFIG_PATH/nomad.service"
        destination = "/etc/systemd/system/nomad.service"
    }
    script {
        apt {
            update = true
        }
        apt {
            pgp = "https://download.docker.com/linux/ubuntu/gpg"
            repository {
                url = "https://download.docker.com/linux/ubuntu"
                sources = "stable"
            }
            install = ["docker-ce", "docker-ce-cli", "containerd.io"]
        }
        apt {
            pgp = "https://apt.releases.hashicorp.com/gpg"
            repository {
                url = "https://apt.releases.hashicorp.com"
                sources = "main"
            }
            install_no_upgrade = ["nomad"]
        }
        commands = [
            "sudo mkdir --parents /opt/nomad",
            "sudo chmod 700 /etc/nomad.d",
            "chown nomad:nomad /etc/nomad.d/server-key.pem",
            "systemctl daemon-reload",
            "systemctl stop nomad",
            "systemctl start nomad",
        ]
    }
}

recipe "nomad.list" "local" {
    commands = [
        "nomad node status -allocs",
        "nomad job status",
        "nomad deployment list",
    ]
}

recipe "nomad.config-client" "remote" {
    match {
        attribute = "tags"
        operator = "contains"
        value = "@golem.NOMAD_CLIENT_TAG"
    }
    artifact {
        template {
            path = "https://raw.githubusercontent.com/sudhanshuraheja/golem-scripts/main/files/nomad_client_template.hcl"
        }
        destination = "/etc/nomad.d/nomad.hcl"
    }
    artifact {
        source = "certs/nomad-ca.pem"
        destination = "/etc/nomad.d/nomad-ca.pem"
    }
    artifact {
        source = "certs/client.pem"
        destination = "/etc/nomad.d/client.pem"
    }
    artifact {
        source = "certs/client-key.pem"
        destination = "/etc/nomad.d/client-key.pem"
    }
    commands = [
        "chown nomad:nomad /etc/nomad.d/client-key.pem",
        "mkdir -p /opt/caddy",
        "chown nomad:nomad /opt/caddy",
        "systemctl daemon-reload",
        "systemctl stop nomad",
        "systemctl start nomad",
    ]
}

recipe "nomad.config-server" "remote" {
    match {
        attribute = "tags"
        operator = "contains"
        value = "@golem.NOMAD_SERVER_TAG"
    }
    artifact {
        source = "configs/nomad_server.hcl"
        destination = "/etc/nomad.d/nomad.hcl"
    }
    artifact {
        source = "certs/nomad-ca.pem"
        destination = "/etc/nomad.d/nomad-ca.pem"
    }
    artifact {
        source = "certs/server.pem"
        destination = "/etc/nomad.d/server.pem"
    }
    artifact {
        source = "certs/server-key.pem"
        destination = "/etc/nomad.d/server-key.pem"
    }
    commands = [
        "chown nomad:nomad /etc/nomad.d/server-key.pem",
        "systemctl daemon-reload",
        "systemctl stop nomad",
        "systemctl start nomad",
    ]
}

recipe "nomad.tail" "remote" {
    match {
        attribute = "tags"
        operator = "contains"
        value = "@golem.NOMAD_TAG"
    }
    script {
        command = "tail -f /var/log/nomad.log"
    }
}