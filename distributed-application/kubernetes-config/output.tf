# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "kubeconfig" {
  value = abspath("${path.root}/${local_sensitive_file.kubeconfig.filename}")
}
