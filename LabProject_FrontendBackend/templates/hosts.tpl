[frontend]
${frontend_public_ip}

[backends]
%{ for ip in backend_public_ips ~}
${ip}
%{ endfor ~}

[all:vars]
ansible_user=${ansible_user}
ansible_ssh_private_key_file=${ansible_ssh_private_key}
ansible_python_interpreter=/usr/bin/python3
