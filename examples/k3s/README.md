# k3s 클러스터 생성 테스트

## 단일 노드 구성

**Terraform 코드 구성**

다음 리소스만으로 구성합니다. (나머지는 주석 처리해 주세요)

- 보안 그룹 (k3s_nodes) 및 관련 규칙
- aws_instance.k3s_single EC2 인스턴스

배포 방법

```shell
terraform init
terraform apply
```

**Ansible로 인스턴스 설정**

```shell
# Inventory 확인
ansible-inventory -i inventory_k3s_single_aws_ec2.yml --graph

# Playbook 실행
ansible-playbook -i inventory_k3s_multi_aws_ec2.yml -u ec2-user --private-key PRIVATE_KEY_PATH playbook-k3s-multi.yaml
```

## 다중 노드 구성 (서버 1 + 에이전트 2)

서버 1, 에이전트 2개로 구성합니다. 

**Terraform 코드 구성**

다음 리소스만으로 구성합니다. (나머지는 주석 처리해 주세요)

- 보안 그룹 (k3s_nodes) 및 관련 규칙
- aws_instance.k3s_multi_server, aws_instance.k3s_multi_agent EC2 인스턴스

배포 방법

```shell
terraform init
terraform apply
```

**Ansible로 인스턴스 설정**

```shell
# Inventory 확인
ansible-inventory -i inventory_k3s_multi_aws_ec2.yml --graph

# Playbook 실행
ansible-playbook -i inventory_k3s_multi_aws_ec2.yml -u ec2-user --private-key PRIVATE_KEY_PATH playbook-k3s-multi.yaml
```

## 고가용성 서버 구성 (서버 3)

서버 3대로 고가용성을 추구하고자 합니다. 이 때 서버는 Control Plane 겸 Data Plane의 역할을 수행합니다. (데이터는 내장 etcd로 관리합니다)

**Terraform 코드 구성**

다음 리소스만으로 구성합니다. (나머지는 주석 처리해 주세요)
- 보안 그룹 (k3s_nodes) 및 관련 규칙
- aws_instance.k3s_ha_server EC2 인스턴스
- LB, Target Group, Target Group Attachment

배포 방법

```shell
terraform init
terraform apply

# nslookup으로 NLB의 공인 IP 주소를 확인하여 메모합니다.
```

**Ansible로 인스턴스 설정**

```shell
# Inventory 확인
ansible-inventory -i inventory_k3s_ha_aws_ec2.yml --graph

# Playbook 실행
# (YOUR_RANDOM_TOKEN 값은 임의의 값으로 생성합니다)
ansible-playbook -i inventory_k3s_ha_aws_ec2.yml -u ec2-user \
--private-key PRIVATE_KEY_PATH \
-e nlb_public_ip=NLB_PUBLIC_IP \
-e k3s_token=YOUR_RANDOM_TOKEN \
playbook-k3s-ha.yaml
```

## 리소스 정리

```shell
terraform destroy
```