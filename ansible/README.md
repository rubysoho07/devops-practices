# Ansible Configuration

## Inventory 설정 

`inventory.yaml` 파일로 저장 

```
test_hosts:
  hosts:
    "(IP_OR_HOSTNAME)":
    # ... 
  vars:
    ansible_user: ec2-user
```

## Inventory 설정 확인 

```shell
$ ansible-inventory -i inventory.yaml --list

# Output
{
    "_meta": {
        "hostvars": {
            "(IP_OR_HOSTNAME)": {
                "ansible_user": "ec2-user"
            }
        }
    },
    "all": {
        "children": [
            "ungrouped",
            "test_hosts"
        ]
    },
    "test_hosts": {
        "hosts": [
            "(IP_OR_HOSTNAME)"
        ]
    }
}
```

## 접속 여부 확인

`KEY_FILE_PATH`는 SSH Private Key 파일의 위치를 적는다.

```shell
ansible test_hosts -m ping -i inventory.yaml --private-key KEY_FILE_PATH
(IP_OR_HOSTNAME) | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.9"
    },
    "changed": false,
    "ping": "pong"
}
```

## Playbook 생성 후 실행

`playbook.yaml` 파일 참조. `KEY_FILE_PATH`는 SSH Private Key 파일의 위치를 적는다.

```shell
ansible-playbook -i inventory.yaml playbook.yaml --private-key KEY_FILE_PATH

PLAY [My first play] **************************************************************************************************************************************************************************************

TASK [Gathering Facts] ************************************************************************************************************************************************************************************
ok: [IP_OR_HOSTNAME]

TASK [Ping my hosts] **************************************************************************************************************************************************************************************
ok: [IP_OR_HOSTNAME]

TASK [Print message] **************************************************************************************************************************************************************************************
ok: [IP_OR_HOSTNAME] => {
    "msg": "Hello world"
}

PLAY RECAP ************************************************************************************************************************************************************************************************
IP_OR_HOSTNAME                : ok=3    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

## 수정 후 실행

```shell
ansible-playbook -i inventory.yaml playbook.yaml --private-key KEY_FILE_PATH
```

## Playbook 실행 전 테스트 

`ansible-playbook` 실행 시 `--check` 옵션을 붙인다. ([참고](https://docs.ansible.com/ansible/2.9/user_guide/playbooks_checkmode.html))

## Dynamic Inventory로 테스트

* `Group = Ansible_Managed_Nodes` 태그를 기준으로 하는 인스턴스를 필터링함
* `ansible/inventory_aws_ec2.yaml` 파일을 인스턴스에 저장
    * 참고: Inventory 파일은 `aws_ec2.(yml|yaml)` 로 끝나야 하며, `plugin: amazon.aws.aws_ec2`를 첫 줄에 넣어야 함
* 그리고 Inventory가 정상적으로 들어갔는지 확인 (NODE_IP로 표시한 부분은 상황에 따라 달라질 수 있음)
* Control Node는 EC2의 정보를 얻을 수 있는 권한이 필요하다. (인스턴스 생성/수정/삭제까지 Ansible에 맡기는 것이 아니라면 AmazonEC2ReadOnlyAccess를 부여)

```shell
ansible-inventory -i inventory_aws_ec2.yaml --graph
@all:
  |--@ungrouped:
  |--@aws_ec2:          # EC2 서버 전체를 포괄하므로, Control Node도 포함
  |  |--ec2-NODE_IP.ap-northeast-2.compute.amazonaws.com
  |  |--ec2-NODE_IP.ap-northeast-2.compute.amazonaws.com
  |  |--ec2-NODE_IP.ap-northeast-2.compute.amazonaws.com
  |  |--ec2-NODE_IP.ap-northeast-2.compute.amazonaws.com
  |--@test_hosts:       # Group = Ansible_Managed_Nodes 태그가 붙은 것들만 해당
  |  |--ec2-NODE_IP.ap-northeast-2.compute.amazonaws.com
  |  |--ec2-NODE_IP.ap-northeast-2.compute.amazonaws.com
  |  |--ec2-NODE_IP.ap-northeast-2.compute.amazonaws.com
```

PEM키의 내용을 복사 후 다음과 같이 Playbook 실행 가능 (키 페어의 이름은 `keypair.pem`으로 저장했고, `chmod 400 keypair.pem` 명령으로 권한을 주었음을 가정)

```shell
ansible-playbook -i inventory_aws_ec2.yaml playbook.yaml --private-key keypair.pem
```

### SSM으로 접속하는 경우

키페어 없이 Systems Manager의 Session Manager로 접속할 수 있다. 기본적으로 S3 버킷을 설정해야 하며, Control Node는 S3 버킷에 대한 접근 권한과 Session Manager 실행 권한이 필요하다. 

참고자료
* [https://docs.ansible.com/ansible/latest/collections/community/aws/aws_ssm_connection.html]
* [https://www.cbui.dev/ansible-with-aws-ssm-inventory/]

```shell
ansible-playbook -i inventory_aws_ec2.yaml playbook.yaml
```

혹시나 문제가 발생하면 `ansible-galaxy collection isntall community.aws --force` 명령으로 강제로 모듈을 업데이트 해 본다. 