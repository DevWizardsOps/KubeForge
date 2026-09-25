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

output "kubeconfig_howto" {
  description = "Como pegar o kubeconfig no seu Mac (rode após o cluster subir)."
  value       = <<-EOT
    # 1) Copie o kubeconfig do server para o seu Mac:
    scp -i vockey.pem ubuntu@${aws_eip.server.public_ip}:~/.kube/config ~/.kube/config-kubeforge

    # 2) Troque o endpoint 127.0.0.1 pelo IP público do server:
    sed -i '' 's#https://127.0.0.1:6443#https://${aws_eip.server.public_ip}:6443#' ~/.kube/config-kubeforge

    # 3) Use:
    export KUBECONFIG=~/.kube/config-kubeforge
    kubectl get nodes -o wide   # deve mostrar ${1 + var.agent_count} nós Ready, ARCH=arm64
  EOT
}
