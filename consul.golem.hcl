recipe "consul.setup-local" "local" {
    commands = [
        // consul-agent-ca.pem -> public key
        // consul-agent-ca-key.pem -> private key
        "consul tls ca create",
        "mv consul-agent-ca.pem @golem.CONSUL_PATH/certs/",
        "mv consul-agent-ca-key.pem @golem.CONSUL_PATH/certs/",

        // do1-server-consul-0.pem -> public key
        // do1-server-consul-0-key.pem -> private key
        "consul tls cert create -server -dc @golem.CONSUL_DC",
        "mv @golem.CONSUL_DC-server-consul-0.pem @golem.CONSUL_PATH/certs/",
        "mv @golem.CONSUL_DC-server-consul-0-key.pem @golem.CONSUL_PATH/certs/",

        // do1-client-consul-0.pem -> public key
        // do1-client-consul-0-key.pem -> private key
        "consul tls cert create -client -dc @golem.CONSUL_DC",
        "mv @golem.CONSUL_DC-client-consul-0.pem @golem.CONSUL_PATH/certs/",
        "mv @golem.CONSUL_DC-client-consul-0-key.pem @golem.CONSUL_PATH/certs/",
    ]
}
