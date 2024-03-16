
#Cloud Resume API Challenge Module
module "resumeapi" {
  source = "github.com/CityHallin/terraform_modules/solutions/cloud_resume_api_challenge"

  # General variables
  project     = "azrac"
  environment = "dev"
  region      = "northcentralus"
}