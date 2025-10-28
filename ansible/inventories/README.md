# Ansible Inventories

**Status:** Production  
**Version:** 1.0  
**Last Updated:** 2025-01-27

## Overview

This directory contains Ansible inventory files for different deployment scenarios and environments.

## Inventory Structure

```text
inventories/
├── production/          # Production environment inventories
├── staging/            # Staging environment inventories
├── development/        # Development environment inventories
└── test/              # Test environment inventories
```

## Usage

### Basic Usage

```bash
# Use specific inventory file
ansible-playbook -i inventories/production/hosts.yml playbook.yml

# Use inventory directory
ansible-playbook -i inventories/production/ playbook.yml
```

### Dynamic Inventories

For cloud environments, consider using dynamic inventories:

```bash
# AWS EC2 dynamic inventory
ansible-playbook -i inventories/aws_ec2.yml playbook.yml

# OpenStack dynamic inventory
ansible-playbook -i inventories/openstack.yml playbook.yml
```

## Environment-Specific Configuration

Each environment directory should contain:

- `hosts.yml` - Main inventory file
- `group_vars/` - Group-specific variables
- `host_vars/` - Host-specific variables
- `ansible.cfg` - Environment-specific Ansible configuration

## Security Considerations

- **Never commit sensitive data** (passwords, API keys) to version control
- **Use Ansible Vault** for encrypting sensitive variables
- **Restrict file permissions** on inventory files containing secrets

## See Also

- [Ansible Documentation](https://docs.ansible.com/)
- [Inventory Best Practices](https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html)
- [Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
