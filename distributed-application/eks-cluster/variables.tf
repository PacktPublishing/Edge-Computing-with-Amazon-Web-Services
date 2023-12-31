variable "cluster_name" {
  type    = string
  default = "distributedcluster"
}

variable "kubernetes_version" {
  type    = string
  default = "1.28"
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


variable "wavelength_zone_id" {
  type = map(any)
  default = {
    atlanta      = "use1-wl1-atl-wlz1"
    boston       = "use1-wl1-bos-wlz1"
    chicago      = "use1-wl1-chi-wlz1"
    dallas       = "use1-wl1-dfw-wlz1"
    denver       = "usw2-wl1-den-wlz1"
    houston      = "use1-wl1-iah-wlz1"
    lasvegas     = "usw2-wl1-las-wlz1"
    losangeles   = "usw2-wl1-lax-wlz1"
    miami        = "use1-wl1-mia-wlz1"
    minneapolis  = "use1-wl1-msp-wlz1"
    newyorkcity  = "use1-wl1-nyc-wlz1"
    phoenix      = "usw2-wl1-phx-wlz1"
    seattle      = "usw2-wl1-sea-wlz1"
    london       = "euw2-wl1-lon-wlz1"
    osaka        = "apne1-wl1-kix-wlz1"
    sanfrancisco = "usw2-wl1-sfo-wlz1"
    seoul        = "apne2-wl1-sel-wlz1"
    tokyo        = "apne1-wl1-nrt-wlz1"
    washingtondc = "use1-wl1-was-wlz1"
  }
}

variable "local_zone_id" {
  type = map(any)
  default = {
    atlanta      = "use1-atl1-az1"
    boston       = "use1-bos1-az1"
    chicago      = "use1-chi1-az1"
    dallas       = "use1-dfw2-az1"
    denver       = "usw2-den1-az1"
    houston      = "use1-iah1-az1"
    lasvegas     = "usw2-las1-az1"
    losangeles   = "usw2-lax1-az1"
    miami        = "use1-mia1-az1"
    minneapolis  = "use1-msp1-az1"
    newyorkcity  = "use1-nyc1-az1"
    phoenix      = "usw2-phx2-az1"
    seattle      = "usw2-sea1-az1"
    london       = "eu-west-2c"
    osaka        = "ap-northeast-2c"
    sanfrancisco = "us-west-2c"
    seoul        = "ap-northeast-2c"
    tokyo        = "ap-northeast-1c"
    washingtondc = "us-east-1c"
  }
}

variable "true_local_zone" {
  type = map(any)
  default = {
    atlanta      = true
    boston       = true
    chicago      = true
    dallas       = true
    denver       = true
    houston      = true
    lasvegas     = true
    losangeles   = true
    miami        = true
    minneapolis  = true
    newyorkcity  = true
    phoenix      = true
    seattle      = true
    london       = false
    osaka        = false
    sanfrancisco = false
    seoul        = false
    tokyo        = false
    washingtondc = false
  }
}
