module "bw_nexus_pk_passphrase" {
  source = "github.com/studio-telephus/terraform-bitwarden-get-item-login.git?ref=1.0.0"
  id     = "0df734c0-cb58-4dd0-8b30-b11e01593b18"
}

module "bw_nexus_user_admin" {
  source = "github.com/studio-telephus/terraform-bitwarden-get-item-login.git?ref=1.0.0"
  id     = "0c1cd311-9e65-4d82-857e-b10600d6e073"
}
