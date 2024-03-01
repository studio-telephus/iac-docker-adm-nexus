locals {
  name              = "nexus"
  docker_image_name = "tel-${var.env}-${local.name}"
  container_name    = "container-${var.env}-${local.name}"
  fqdn              = "nexus.docker.${var.env}.acme.corp"
  nexus_address     = "https://${local.fqdn}/nexus"
}

resource "docker_image" "nexus" {
  name         = local.docker_image_name
  keep_locally = false
  build {
    context = path.module
    build_args = {
      _SERVER_KEY_PASSPHRASE = module.bw_nexus_pk_passphrase.data.password
    }
  }
  triggers = {
    dir_sha1 = sha1(join("", [
      filesha1("${path.module}/Dockerfile")
    ]))
  }
}

resource "docker_volume" "nexus_data" {
  name = "volume-${var.env}-nexus-data"
}

resource "docker_container" "nexus" {
  name     = local.container_name
  image    = docker_image.nexus.image_id
  restart  = "unless-stopped"
  hostname = local.container_name
  shm_size = 1024

  networks_advanced {
    name         = "${var.env}-docker"
    ipv4_address = "10.10.0.120"
  }

  env = [
    "NEXUS_CONTEXT=/nexus",
    "NEXUS_SECURITY_INITIAL_PASSWORD=${module.bw_nexus_user_admin.data.initial_password}",
    "NEXUS_SECURITY_RANDOMPASSWORD=false",
    "INSTALL4J_ADD_VM_PARAMS=-Xms2703M -Xmx2703M -XX:MaxDirectMemorySize=2703M -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -Djava.util.prefs.userRoot=/nexus-data/javaprefs"
  ]

  volumes {
    volume_name    = docker_volume.nexus_data.name
    container_path = "/nexus-data"
    read_only      = false
  }
}
