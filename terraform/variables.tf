# default region
variable "region" {
    type = string
    default = ""
}

# account id
variable "accountId" {
  type = string
  default = ""
}

# aws profile to use (~.aws/credentials)
variable "profile" {
    type = string
    default = ""
}

# default subnet mappings
variable "az" {
    type = map
    default = {
        "a" = "",
        "b" = "",
        "c" = ""
    }
}

# project name
variable "name" {
  type = string
  default = ""
}