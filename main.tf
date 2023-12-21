module "container_adm_artifactory" {
  source    = "github.com/studio-telephus/terraform-lxd-instance.git?ref=1.0.1"
  name      = "container-adm-artifactory"
  image     = "images:debian/bookworm"
  profiles  = ["limits", "fs-dir", "nw-adm"]
  autostart = true
  nic = {
    name = "eth0"
    properties = {
      nictype        = "bridged"
      parent         = "adm-network"
      "ipv4.address" = "10.0.10.120"
    }
  }
  mount_dirs = [
    "${path.cwd}/filesystem-shared-ca-certificates",
    "${path.cwd}/filesystem",
  ]
  exec_enabled = true
  exec         = "/mnt/install.sh"
  environment = {
    RANDOM_STRING               = "e4534916-cd19-44e3-8d70-9c4cabbe426e"
    SERVER_KEYSTORE_STOREPASS   = var.server_keystore_storepass
    SERVER_TRUSTSTORE_STOREPASS = var.server_truststore_storepass
  }
}
