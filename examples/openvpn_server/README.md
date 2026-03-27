# OpenVPN 서버 및 클라이언트 설정 자동화 

이 폴더에서는 다음 작업을 수행합니다. 

- Terraform으로 OpenVPN 서버 및 Private Subnet 내 서버 생성 (+관련 리소스 생성됨)
- Ansible로 OpenVPN 서버와 클라이언트 생성

여기까지 작업한 내용은 OpenVPN을 통해 Private Subnet에 있는 서버에 접근 가능함을 검증했습니다. 필요에 따라 접근 가능한 범위를 줄이는 경우와 같이 추가 설정을 해야 할 수 있습니다. 

## Terraform

terraform.tfvars 파일에 다음 내용을 설정합니다. 

```hcl
keypair_name = "키 페어 이름"
openvpn_inbound_cidr = "OpenVPN으로 접속하는 범위를 제어해야 할 때 IP 주소 범위를 입력"
```

main.tf 파일 내 서브넷 관련 설정은 상황에 맞게 변경해야 합니다.

init -> plan -> apply 순으로 테스트하면 됩니다. 

## Ansible

Terraform으로 서버를 구성했다면 다음과 같이 실행해 볼 수 있습니다. 

```shell
cd ansible

# Inventory 확인
ansible-inventory -i inventory_aws_ec2.yml --graph

# 서버 설정
ansible-playbook -i inventory_aws_ec2.yml -u rocky --private-key (SSH_KEY 경로) playbook-openvpn-server.yaml

# 클라이언트 생성
ansible-playbook -i inventory_aws_ec2.yml -u rocky --private-key (SSH_KEY 경로) -e openvpn_username=(사용자 이름) playbook-openvpn-client.yaml 

# (사용자 이름).ovpn 파일 다운로드 여부를 확인합니다. 
```

## macOS 기준 검증 방법

1. Tunnelblick을 설치합니다. 
2. Tunnelblick을 실행하여, 다운로드 받은 `(사용자 이름).ovpn` 파일을 추가합니다. 
3. `ssh` 명령으로 Private Subnet에 있는 서버에 접근 가능한지 확인합니다.