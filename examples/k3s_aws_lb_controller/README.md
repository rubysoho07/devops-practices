# k3s에서 AWS Load Balancer Controller 사용하기

EC2 인스턴스 3대(서버 1 + 에이전트 2)로 k3s 클러스터를 만들고, AWS Load Balancer Controller로 ALB(Ingress)와 NLB(Service)를 생성합니다.

## 구성

AWS Load Balancer Controller는 노드의 `spec.providerID`(`aws:///ap-northeast-2a/i-xxxx`)로 인스턴스 ID를 알아내어 타겟 그룹에 등록합니다. k3s에 내장된 Cloud Controller Manager는 이 값을 `k3s://노드이름`으로 채우기 때문에, 내장 Cloud Controller Manager를 끄고 [AWS Cloud Controller Manager](https://github.com/kubernetes/cloud-provider-aws)를 대신 배포합니다.

| 구성 요소 | 설정 | 이유 |
| --- | --- | --- |
| k3s 서버 | `disable-cloud-controller: true` | 내장 Cloud Controller Manager 비활성화 |
| k3s 서버, 에이전트 | `kubelet-arg: cloud-provider=external` | 외부 Cloud Controller Manager가 노드를 초기화하도록 지정 |
| k3s 서버, 에이전트 | `node-name: (Private DNS 이름)` | AWS Cloud Controller Manager가 노드 이름으로 인스턴스를 찾음 |
| k3s 서버 | `disable: [servicelb, traefik]` | 로드밸런서와 Ingress를 AWS Load Balancer Controller가 담당 |
| AWS Cloud Controller Manager | `--controllers=*,-route,-service` | 노드 초기화만 담당 (로드밸런서를 중복 생성하지 않도록 함) |

두 컨트롤러는 k3s에 내장된 Helm Controller로 설치합니다. Ansible이 서버의 `/var/lib/rancher/k3s/server/manifests/` 경로에 HelmChart 매니페스트를 두면 k3s가 자동으로 배포합니다.

### Terraform으로 만드는 리소스

- EC2 인스턴스 3대: `k3s-aws-lbc-server`, `k3s-aws-lbc-agent-0`, `k3s-aws-lbc-agent-1` (Public Subnet 2A, 2B, 2C에 1대씩)
  - `kubernetes.io/cluster/k3s-aws-lbc = owned` 태그 (AWS Cloud Controller Manager가 요구)
  - IMDSv2 hop limit 2 (Pod에서 인스턴스 프로파일 자격 증명을 가져오기 위함)
- IAM Role, 인스턴스 프로파일 및 정책 2개 (AWS Cloud Controller Manager용, AWS Load Balancer Controller용)
- 보안 그룹 (k3s-aws-lbc-nodes) 및 관련 규칙
- Public Subnet의 `kubernetes.io/role/elb = 1` 태그 (로드밸런서를 만들 서브넷 자동 탐색용)

## Terraform

terraform.tfvars 파일에 다음 내용을 설정합니다.

```hcl
keypair_name = "키 페어 이름"

# (선택) SSH(22), Kubernetes API(6443)에 접근할 수 있는 IP 주소 범위. 기본값은 0.0.0.0/0
admin_cidr_blocks = ["내 IP 주소/32"]
```

main.tf 파일 내 서브넷 관련 설정(`public_subnet_names`)은 상황에 맞게 변경해야 합니다.

```shell
cd terraform

terraform init
terraform apply
```

## Ansible

```shell
cd ansible

# Inventory 확인 (k3s_server 1대, k3s_agent 2대)
ansible-inventory -i inventory_aws_ec2.yml --graph

# Playbook 실행
ansible-playbook -i inventory_aws_ec2.yml --private-key PRIVATE_KEY_PATH playbook-k3s-aws-lbc.yaml
```

Playbook은 다음 순서로 진행합니다.

1. 서버에 k3s 설정 파일을 만들고 k3s를 설치한 뒤, HelmChart 매니페스트 2개를 배포
2. 에이전트 2대를 클러스터에 추가
3. 모든 노드에 providerID가 설정되고, AWS Load Balancer Controller가 준비될 때까지 대기

k3s와 각 컨트롤러의 버전은 `group_vars/all.yaml` 파일에서 관리합니다.

## 확인

Playbook을 실행한 경로에 kubeconfig 파일(`kubeconfig-k3s-aws-lbc.yaml`)이 만들어집니다.

```shell
export KUBECONFIG=$PWD/kubeconfig-k3s-aws-lbc.yaml

# 모든 노드의 PROVIDER_ID가 aws:///(AZ)/(인스턴스 ID) 형식인지 확인
kubectl get nodes -o custom-columns=NAME:.metadata.name,PROVIDER_ID:.spec.providerID

kubectl -n kube-system get daemonset/aws-cloud-controller-manager deployment/aws-load-balancer-controller
```

### ALB (Ingress)

```shell
kubectl apply -f ../manifests/sample-alb.yaml

# ADDRESS에 ALB의 DNS 이름이 표시됩니다. (ALB가 active 상태가 될 때까지 2~3분 소요)
kubectl get ingress sample-app
curl http://ALB_DNS_NAME
```

### NLB (Service)

```shell
kubectl apply -f ../manifests/sample-nlb.yaml

# EXTERNAL-IP에 NLB의 DNS 이름이 표시됩니다.
kubectl get service sample-app-nlb
curl http://NLB_DNS_NAME
```

문제가 있을 때는 컨트롤러 로그를 확인합니다.

```shell
kubectl -n kube-system logs deployment/aws-load-balancer-controller
kubectl -n kube-system logs daemonset/aws-cloud-controller-manager
```

## 리소스 정리

ALB, NLB와 관련 보안 그룹은 Terraform이 아니라 AWS Load Balancer Controller가 만든 리소스입니다. **반드시 Ingress와 Service를 먼저 삭제한 뒤** `terraform destroy`를 실행합니다. 순서를 바꾸면 로드밸런서가 계정에 그대로 남습니다.

```shell
kubectl delete -f ../manifests/sample-nlb.yaml -f ../manifests/sample-alb.yaml

# 로드밸런서가 모두 삭제되었는지 확인 (결과가 비어 있어야 함)
aws elbv2 describe-load-balancers --query "LoadBalancers[?starts_with(LoadBalancerName, 'k8s-')].LoadBalancerName"

cd ../terraform
terraform destroy
```

## 참고 사항

- 타겟 유형은 `instance`만 사용할 수 있습니다. Flannel이 할당한 Pod IP는 VPC에서 라우팅되지 않으므로 `ip` 타겟은 동작하지 않습니다. Ingress가 가리키는 Service는 `NodePort` 유형이어야 합니다.
- NLB를 만드는 Service에는 `loadBalancerClass: service.k8s.aws/nlb`를 지정합니다. (AWS Load Balancer Controller의 Webhook이 새로 만드는 LoadBalancer Service에 자동으로 넣어주기도 합니다)
- k3s에는 IRSA가 없어 컨트롤러가 노드의 인스턴스 프로파일 권한을 사용합니다. 즉, 노드에서 실행되는 모든 Pod가 같은 권한을 가질 수 있습니다.
- AWS Cloud Controller Manager 이미지 버전(`aws_ccm_image_tag`)은 k3s의 Kubernetes 마이너 버전과 맞춥니다.
- AWS Load Balancer Controller 버전을 올릴 때는 `terraform/policies/aws_load_balancer_controller.json` 파일도 해당 버전의 [iam_policy.json](https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/install/iam_policy.json)으로 교체합니다.

## 참고자료

- [k3s - Deploying an External Cloud Controller Manager](https://docs.k3s.io/networking/networking-services#deploying-an-external-cloud-controller-manager)
- [k3s - Helm Controller](https://docs.k3s.io/add-ons/helm)
- [AWS Cloud Controller Manager - Prerequisites](https://cloud-provider-aws.sigs.k8s.io/prerequisites/)
- [AWS Load Balancer Controller - Installation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/)
- [AWS Load Balancer Controller - Subnet Auto-Discovery](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/subnet_discovery/)
