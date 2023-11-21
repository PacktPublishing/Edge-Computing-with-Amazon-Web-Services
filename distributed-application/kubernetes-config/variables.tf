variable "cluster_name" {
  type    = string
  default = "distributedcluster"
}

variable "edge_city" {
  type    = string
  default = "atlanta"
}

variable "parent_region" {
  type = map(any)
  default = {
    atlanta      = "us-east-1"
    boston       = "us-east-1"
    chicago      = "us-east-1"
    dallas       = "us-east-1"
    denver       = "us-west-2"
    houston      = "us-east-1"
    lasvegas     = "us-west-2"
    losangeles   = "us-west-2"
    miami        = "us-east-1"
    minneapolis  = "us-east-1"
    newyorkcity  = "us-east-1"
    phoenix      = "us-east-1"
    seattle      = "us-east-1"
    london       = "eu-west-2"
    osaka        = "ap-northeast-1"
    sanfrancisco = "us-west-2"
    seoul        = "ap-northeast-2"
    tokyo        = "ap-northeast-1"
    washingtondc = "us-east-1"
  }
}

