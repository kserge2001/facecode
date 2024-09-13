variable "region" {
 type = string
 default = "us-east-1" #replace by the AWS region where you want to create your infrastructure 
}

variable "bucket_name" {
type = string
 description = "The name of the bucket use for host the website"
 default = "bucketparlai-serge" #replace by the name of the bucket you want to create
}

variable "cp-path" {
type = string
description = "PATH where the website files are located"
default = "website/build" #replace by the name of the path where the files of your website are located
}



