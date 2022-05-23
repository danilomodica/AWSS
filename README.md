# AWSS - DNA Substring Matching
[![forthebadge](https://svgshare.com/i/hHw.svg)](https://forthebadge.com)
[![forthebadge](https://forthebadge.com/images/badges/built-with-love.svg)](https://forthebadge.com)

[![CICD](https://github.com/domenico-rgs/AWSS/actions/workflows/main.yml/badge.svg)](https://github.com/domenico-rgs/AWSS/actions/workflows/main.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Cloud-based web application that allows to calculate, given two strings of DNA, the longest common substring.

### Software and services used
- [AWS](https://aws.amazon.com/)
- [Docker](https://www.docker.com/) - version 20.10.16
- [Bootstrap](https://getbootstrap.com/) - version 5.1.3
- [Terraform](https://www.terraform.io/) - CLI version 1.2.0 • provider hashicorp/aws v4.15.0

### Programming languages used
- C - version C11
- [Python](https://www.python.org/) - version 3.9
- [Node.js](https://nodejs.org/it/) - version 14.x

## Setting up
Various settings can be changed by modifying the file **main.tf**

In particular they are:

* *region* : specify the aws region where you want to deploy the infrastructure
* *service_name*: name of the service, awss in this case
* *website_url* url of the website that will host the webapp
* *email* : gmail email used to send notification to the user at the end of a computation (you can change provider in src/sendMail.py code)
* *certificate related variables* : variables related to the website certificates for www and non-www domains
* *masterPass* and *masterName*: are the credentials to access to the OpenSearch dashboard

## Infrastructure building
After changing the settings according to your preferences, to run the terraform code in order to build the whole infrastructure, open a terminal and run the following commands.

```console
$ cd terraform
$ terraform init
$ terraform apply -auto-approve
```

At the third step you will be asked to insert your AWS access key and secret key.

After executing the commands above the output will be the DNS nameservers to be set on your domain registrar in order to have access to the web interface and the url of the OpenSearch dashboard used to look at the logs.

[//]: <> (Aggiungere spiegazioni su avvio container e/o pipeline se non automatizzati e eventualmente login su terraform cloud)