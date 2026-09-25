output "server_public_ip" {
  description = "IP público (Elastic IP) do nó server — use para SSH e para o k3s API."
  value       = aws_eip.server.public_ip
}

output "server_private_ip" {
  description = "IP privado do server (usado pelos agents para o join)."
  value       = aws_instance.server.private_ip
}

output "agent_public_ips" {
  description = "IPs públicos dos nós agent."
  value       = aws_instance.agent[*].public_ip
}

output "cluster_sizing" {
  description = "Resumo do dimensionamento do cluster."
  value       = "${1 + var.agent_count} nó(s) [1 server + ${var.agent_count} agent(s)] x ${var.instance_type}"
}

output "ssh_server" {
  description = "Comando SSH para o server."
  value       = "ssh -i vockey.pem ubuntu@${aws_eip.server.public_ip}"
}

output "cluster_endpoint" {
  description = "Endpoint do k3s API — hostname Dynu se configurado, senão o IP público."
  value       = local.dynu_hostname != "" ? "https://${local.dynu_hostname}:6443" : "https://${aws_eip.server.public_ip}:6443"
}

locals {
  _howto_ddns = <<-EOT
    # DDNS ativo (${local.dynu_hostname}) — endpoint estável, sem 'sed' de IP entre sessões:
    scp -i vockey.pem ubuntu@${aws_eip.server.public_ip}:~/.kube/config ~/.kube/config-kubeforge
    sed -i '' 's#https://127.0.0.1:6443#https://${local.dynu_hostname}:6443#' ~/.kube/config-kubeforge
    export KUBECONFIG=~/.kube/config-kubeforge
    kubectl get nodes -o wide   # ${1 + var.agent_count} nós Ready, ARCH=arm64
    # Nas próximas sessões o IP muda mas o hostname NÃO — reuse o mesmo kubeconfig.
  EOT

  _howto_ip = <<-EOT
    # Sem DDNS — use o IP público (muda a cada sessão):
    scp -i vockey.pem ubuntu@${aws_eip.server.public_ip}:~/.kube/config ~/.kube/config-kubeforge
    sed -i '' 's#https://127.0.0.1:6443#https://${aws_eip.server.public_ip}:6443#' ~/.kube/config-kubeforge
    export KUBECONFIG=~/.kube/config-kubeforge
    kubectl get nodes -o wide   # ${1 + var.agent_count} nós Ready, ARCH=arm64
  EOT
}

output "kubeconfig_howto" {
  description = "Como pegar o kubeconfig no seu Mac (rode após o cluster subir)."
  value       = local.dynu_hostname != "" ? local._howto_ddns : local._howto_ip
}
