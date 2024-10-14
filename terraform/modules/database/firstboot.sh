#!/bin/bash
dnf makecache
dnf install git ansible-core -y
ansible-galaxy collection install amazon.aws
ansible-pull -U https://github.com/Traktopel/wpov.git ansible/playbook.yaml -e 'bucket="${bucket}" noderole="{noderole}"'
echo "${bucket}" >> /root/asd.txt
echo "${noderole}" >> /root/asd.txt