#!/bin/bash
dnf makecache
dnf install git ansible-core -y
ansible-galaxy collection install amazon.aws
ansible-pull -U https://github.com/Traktopel/wpov.git -e playbook_dir ansible/playbook.yaml -e bucket ${bucket}
echo "${bucket}" >> /root/asd.txt