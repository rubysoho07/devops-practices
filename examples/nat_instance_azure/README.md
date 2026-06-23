# Azure NAT Instance (Terraform)

Azure 환경에 NAT Instance를 구성하는 Terraform 코드입니다.

## 아키텍처

```
[Private Subnet VM] → [Route Table: 0.0.0.0/0 → NAT Instance] → [NAT Instance] → [인터넷]
```

- Private 서브넷의 아웃바운드 트래픽이 NAT 인스턴스를 경유해 인터넷으로 나갑니다.

## 생성 리소스

| 리소스 | 이름 | 설명 |
|---|---|---|
| `azurerm_public_ip` | `pip-nat-instance` | NAT 인스턴스 공인 IP (Static) |
| `azurerm_network_security_group` | `nsg-nat-instance` | SSH(22) 및 VNet 내부 트래픽 허용 |
| `azurerm_network_interface` | `nic-nat-instance` | IP Forwarding 활성화 |
| `azurerm_linux_virtual_machine` | `vm-nat-instance` | Rocky Linux 9, Standard_B2as_v2 |
| `azurerm_route_table` | `rt-private` | `0.0.0.0/0` → NAT 인스턴스 Private IP |
| `azurerm_network_security_group` | `nsg-private` | Private 서브넷용 NSG |

## 사전 요구사항

기존에 생성된 아래 리소스가 필요합니다.

- Resource Group
- VNet
- Public 서브넷 (NAT 인스턴스 배치용)
- Private 서브넷 (라우팅 대상)
- Azure SSH 공개 키 리소스

## 사용 방법

### 1. 변수 설정

`terraform.tfvars` 파일에 값을 입력합니다.

```hcl
resource_group_name = "your-rg"
vnet_name           = "your-vnet"
subnet_name         = "your-public-subnet"
private_subnet_name = "your-private-subnet"
admin_username      = "azureuser"
ssh_public_key_name = "your-ssh-key-name"
```

### 2. 배포

```bash
terraform init
terraform plan
terraform apply
```

## NAT 동작 방식

`user_data.sh`가 VM 초기 부팅 시 실행되어 아래를 설정합니다.

- `sysctl`로 IPv4 포워딩 영구 활성화 (`net.ipv4.ip_forward = 1`)
- `iptables` MASQUERADE 규칙으로 아웃바운드 트래픽 NAT 처리
- `iptables` 규칙 영구 저장

NAT 규칙 확인:

```bash
iptables -t nat -L -n -v
```

## Outputs

| Output | 설명 |
|---|---|
| `nat_instance_public_ip` | NAT 인스턴스 공인 IP |
| `nat_instance_private_ip` | NAT 인스턴스 사설 IP |
