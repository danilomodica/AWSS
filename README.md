# AWSS - DNA Substring Matching
Cloud based and multi-user HPC application that measure the similarity between two genomic sequences.

### Software used
- [AWS](https://aws.amazon.com/)
- [Bootstrap](https://getbootstrap.com/) - version 5.1.3
- [Terraform](https://www.terraform.io/) - CLI version 1.1.7 • provider hashicorp/aws v4.5.0

## Infrastructure building
Create a .tfvars file which will contain Amazon AWS access key and secret key and then run as follow:

```console
cd terraform
terraform apply -auto-approve -var-file="credentials.tfvars"
```

The region used, default eu-central-1 (Frankfurt), can be modified in _config.tf_. 
After executing the commands above the output will be the DNS nameservers to be set on your domain registrar in order to have access to the web interface.