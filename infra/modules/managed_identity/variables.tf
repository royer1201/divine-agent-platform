variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "role_assignments" {
  description = "Map of a static label to {scope, role}. Labels must be known at plan time."
  type = map(object({
    scope = string
    role  = string
  }))
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
