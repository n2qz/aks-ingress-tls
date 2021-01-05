# aks-ingress-tls

Nicholas S. Castellano

Terraform deployment of an AKS cluster with TLS-enabled ingress and a
demo application.

## Installation

Requires an existing Azure subscription and a custom domain with a DNS Zone in Azure.

Requires the [Terraform](https://www.terraform.io/) CLI to perform the resource deployment.

Requires the [Azure
CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
installed and logged into an Azure account with sufficient privileges
to create the resources, or you can modify the code to pass
credentials directly to the azurerm provider in the usual ways.

## Usage

Create a terraform.tfvars and populate it with the configuration variables:

```terraform
email                  = "email@example.com"
zone-name              = "az.example.com"
zone-rg                = "rg-dns"
ingress-subdomain-name = "testcluster"
letsencrypt-acme-api   = "production" # It is advisable to use "staging" until you're confident
aks-name               = "testcluster"
aks-rg-name            = "rg-aks"
aks-location           = "eastus2"
```

Log into your Azure account:

```bash
az login
```

Deploy:

```bash
terraform init
terraform apply
```

Then run a browser to interact with the application, for example:

```bash
lynx https://testcluster.az.example.com/hello-world-one
lynx https://testcluster.az.example.com/hello-world-two
```

## Contributing

Pull requests are welcome. For major changes, please open an issue
first to discuss what you would like to change.

## Credits

This is intended to be a more-or-less direct translation of the
Microsoft demo deployment "[Create an HTTPS ingress controller on Azure
Kubernetes Service
(AKS)](https://docs.microsoft.com/en-us/azure/aks/ingress-tls)"

## License

Released in the public domain 2021-01-04 under the [CC0 1.0 Universal
license](https://creativecommons.org/publicdomain/zero/1.0/deed.en)
