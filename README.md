# AWSS - DNA Substring Matching
[![forthebadge](https://svgshare.com/i/hHw.svg)](https://forthebadge.com)
[![forthebadge](https://forthebadge.com/images/badges/built-with-love.svg)](https://forthebadge.com)

[![CICD](https://github.com/domenico-rgs/AWSS/actions/workflows/main.yml/badge.svg)](https://github.com/domenico-rgs/AWSS/actions/workflows/main.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Cloud-based Web Application to compute the longest common substring between two DNA strings. \
**doc/** directory contains all the useful documentation about the project.

### Software and services used
- [AWS](https://aws.amazon.com/)
- [Docker](https://www.docker.com/) - version 20.10.16
- [Bootstrap](https://getbootstrap.com/) - version 5.1.3
- [Terraform](https://www.terraform.io/) - CLI version 1.2.1 • provider hashicorp/aws v4.16.0

### Programming languages used
- C - version C11
- JavaScript
- [Python](https://www.python.org/) - version 3.9
- [Node.js](https://nodejs.org/it/) - version 14.x

## Setting up
Various settings can be changed by modifying the file **main.tf**

In particular they are:

* *region* : the AWS region where you want to deploy the infrastructure <br>
Note: the region must be modified even in the *conf.ini* file present in the *docker* folder
* *service_name*: the name of the service, awss in our case
* *website_url*: the URL of the website that will host the webapp
* *email* : the Gmail email used to send notification to the user at the end of a computation (you can change the provider by editing the code in src/sendMail.py)
* *acm_certificate_arn* and *route_zone_id* : variables related to the website certificate and the id of the hosted zone in AWS Route53 (the hosted zone should be created manually a prior as well as the SSL/TLS certificate, the hosted zone should contain only SOA, NS and certificare CNAME records)
* *masterPass* and *masterName*: the credentials to access to the OpenSearch dashboard

Other variables values, such as passwords, will be asked during the deployment.

## Infrastructure building
Three possible ways to deploy the infrastructure:

1. After changing the settings according to your preferences in the main.tf file (and also settings about Terraform Cloud in the *terraform* block), run the code on Terraform Cloud by opening a terminal on the project folder and running the following commands:

```console
$ cd terraform
$ terraform login
$ terraform init
$ terraform apply -auto-approve
```

2. If you want to deploy the infrastructure locally, delete the "cloud" block within the *terraform* statement on *main.tf*, then simply run:

```console
$ terraform init
$ terraform apply -auto-approve
```

3. Use GitHub Actions to automatically deploy the infrastructure: see our documented workflow in the .github folder 

Note: during the deployment, you will be asked to insert your AWS access key and secret key, your Gmail and OpenSearch passwords. You can set these variables on Terraform Cloud dashboard or on a *.tfvars* file, so that they will not be asked every time.
