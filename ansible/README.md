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