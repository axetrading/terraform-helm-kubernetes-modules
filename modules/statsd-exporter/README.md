<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.36 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.10.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.10.0 |

## Resources

| Name | Type |
|------|------|
| [helm_release.statsd_exporter](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Enable statsd-exporter | `bool` | `false` | no |
| <a name="input_statsd_exporter_version"></a> [statsd\_exporter\_version](#input\_statsd\_exporter\_version) | Version of the statsd-exporter Helm chart | `string` | `"0.13.0"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_statsd_exporter"></a> [statsd\_exporter](#output\_statsd\_exporter) | Statsd Exporter Release Details |
<!-- END_TF_DOCS -->