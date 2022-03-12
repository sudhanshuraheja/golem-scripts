recipe "docker.setup" "remote" {
    match {
        attribute = "tags"
        operator = "contains"
        value = "@golem.DOCKER_SERVER_TAG"
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
    }
}