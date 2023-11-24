variable "cluster_name" {
  type    = string
  default = "distributedcluster"
}

variable "edge_city" {
  type    = string
  default = "atlanta"
}

variable "wavelength_zone" {
  type = map(any)
  default = {
    atlanta      = "us-east-1-wl1-atl-wlz-1"
    boston       = "us-east-1-wl1-bos-wlz-1"
    chicago      = "us-east-1-wl1-chi-wlz-1"
    dallas       = "us-east-1-wl1-dfw-wlz-1"
    denver       = "us-west-2-wl1-den-wlz-1"
    houston      = "us-east-1-wl1-iah-wlz-1"
    lasvegas     = "us-west-2-wl1-las-wlz-1"
    losangeles   = "us-west-2-wl1-lax-wlz-1"
    miami        = "us-east-1-wl1-mia-wlz-1"
    minneapolis  = "us-east-1-wl1-msp-wlz-1"
    newyorkcity  = "us-east-1-wl1-nyc-wlz-1"
    phoenix      = "us-west-2-wl1-phx-wlz-1"
    seattle      = "us-west-2-wl1-sea-wlz-1"
    london       = "eu-west-2-wl1-lon-wlz-1"
    osaka        = "ap-northeast-1-wl1-kix-wlz-1"
    sanfrancisco = "us-west-2-wl1-sfo-wlz-1"
    seoul        = "ap-northeast-2-wl1-sel-wlz-1"
    tokyo        = "ap-northeast-1-wl1-nrt-wlz-1"
    washingtondc = "us-east-1-wl1-was-wlz-1"
  }
}

variable "local_zone" {
  type = map(any)
  default = {
    atlanta      = "us-east-1-atl-1a"
    boston       = "us-east-1-bos-1a"
    chicago      = "us-east-1-chi-1a"
    dallas       = "us-east-1-dfw-2a"
    denver       = "us-west-2-den-1a"
    houston      = "us-east-1-iah-1a"
    lasvegas     = "us-west-2-las-1a"
    losangeles   = "us-west-2-lax-1a"
    miami        = "us-east-1-mia-1a"
    minneapolis  = "us-east-1-msp-1a"
    newyorkcity  = "us-east-1-nyc-1a"
    phoenix      = "us-west-2-phx-2a"
    seattle      = "us-west-2-sea-1a"
    london       = "eu-west-2c"
    osaka        = "ap-northeast-1c"
    sanfrancisco = "us-west-2c"
    seoul        = "ap-northeast-2c"
    tokyo        = "ap-northeast-1c"
    washingtondc = "us-east-1c"
  }
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

variable "wavelength_group_name" {
  type = map(any)
  default = {
    atlanta      = "us-east-1-wl1"
    boston       = "us-east-1-wl1"
    chicago      = "us-east-1-wl1"
    dallas       = "us-east-1-wl1"
    denver       = "us-west-2-wl1"
    houston      = "us-east-1-wl1"
    lasvegas     = "us-west-2-wl1"
    losangeles   = "us-west-2-wl1"
    miami        = "us-east-1-wl1"
    minneapolis  = "us-east-1-wl1"
    newyorkcity  = "us-east-1-wl1"
    phoenix      = "us-east-1-wl1"
    seattle      = "us-east-1-wl1"
    london       = "eu-west-2-wl1"
    osaka        = "ap-northeast-1-wl1"
    sanfrancisco = "us-west-2-wl1"
    seoul        = "ap-northeast-2-wl1"
    tokyo        = "ap-northeast-1-wl1"
    washingtondc = "us-east-1-wl1"
  }
}

variable "local_zone_group_name" {
  type = map(any)
  default = {
    atlanta      = "us-east-1-atl-1"
    boston       = "us-east-1-bos-1"
    chicago      = "us-east-1-chi-1"
    dallas       = "us-east-1-dfw-2"
    denver       = "us-west-2-den-1"
    houston      = "us-east-1-iah-1"
    lasvegas     = "us-west-2-las-1"
    losangeles   = "us-west-2-lax-1"
    miami        = "us-east-1-mia-1"
    minneapolis  = "us-east-1-msp-1"
    newyorkcity  = "us-east-1-nyc-1"
    phoenix      = "us-west-2-phx-2"
    seattle      = "us-west-2-sea-1"
    london       = "eu-west-2"
    osaka        = "ap-northeast-2"
    sanfrancisco = "us-west-2"
    seoul        = "ap-northeast-2"
    tokyo        = "ap-northeast-1"
    washingtondc = "us-east-1"
  }
}



