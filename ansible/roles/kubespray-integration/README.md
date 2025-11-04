# Kubespray Integration Role

This role prepares the Kubespray environment for Kubernetes cluster deployment by building and
installing Kubespray as an Ansible collection.

## Role Structure

```text
kubespray-integration/
├── defaults/
│   └── main.yml          # Default variables
├── tasks/
│   ├── main.yml          # Entry point - includes prepare.yml
│   └── prepare.yml       # Preparation and setup tasks
└── README.md
```

## Architecture

This role uses **Kubespray as an Ansible Collection** (kubernetes_sigs.kubespray). This provides:

✅ **Native Ansible integration** - No shell module workarounds  
✅ **Real-time output** - Direct playbook execution with full visibility  
✅ **Proper role resolution** - Collection namespace handles paths correctly  
✅ **Better error handling** - Ansible's native error reporting  
✅ **Clean architecture** - Uses `import_playbook` with collection-qualified paths  

### Preparation Phase (`prepare.yml`):

- Validates Kubespray installation
- Verifies inventory file exists
- Resolves absolute paths
- **Builds Kubespray as an Ansible collection**
- **Installs the collection** to `ansible/collections/`

## Variables

### Default Variables (in `defaults/main.yml`):

| Variable | Default | Description |
|----------|---------|-------------|
| `kubespray_source_dir` | `{{ playbook_dir }}/../../build/3rd-party/kubespray/kubespray-src` | Path to Kubespray source |
| `kubespray_inventory_file` | `output/cluster-state/inventory.yml` | Path to inventory (relative or absolute) |
| `kubespray_collection_namespace` | `kubernetes_sigs` | Collection namespace |
| `kubespray_collection_name` | `kubespray` | Collection name |
| `kubespray_collection_version` | `2.29.0` | Collection version |
| `collections_path` | `{{ playbook_dir }}/../collections` | Collections installation path |

### Runtime Variables (set by role):

- `kubespray_source_dir_abs` - Absolute path to Kubespray source
- `kubespray_inventory_abs` - Absolute path to inventory file

## Usage

### In a Playbook:

```yaml
---
- name: Prepare Kubespray Environment
  hosts: localhost
  gather_facts: false
  connection: local
  become: false
  vars:
    kubespray_source_dir: "{{ playbook_dir }}/../../build/3rd-party/kubespray/kubespray-src"
    kubespray_inventory_file: "output/cluster-state/inventory.yml"
  roles:
    - role: kubespray-integration
      tags: ['prepare']

# Then import the Kubespray collection playbook
- name: Deploy Kubernetes Cluster
  import_playbook: kubernetes_sigs.kubespray.cluster
```

### Available Kubespray Collection Playbooks:

Once the collection is installed, you can use:

- `kubernetes_sigs.kubespray.cluster` - Deploy Kubernetes cluster
- `kubernetes_sigs.kubespray.scale` - Scale the cluster
- `kubernetes_sigs.kubespray.upgrade_cluster` - Upgrade cluster version
- `kubernetes_sigs.kubespray.reset` - Reset/teardown cluster
- `kubernetes_sigs.kubespray.remove_node` - Remove specific node

## Prerequisites

1. **Kubespray source** must be installed:

   ```bash
   cmake --build build --target install-kubespray
   ```

2. **Inventory file** must exist (use `make cloud-cluster-inventory`)

3. **distlib** Python package (automatically installed):

   ```bash
   uv pip install distlib
   ```

## Environment Variables

When running playbooks that use this role, set:

```bash
ANSIBLE_COLLECTIONS_PATH=ansible/collections
```

This ensures Ansible can find the installed Kubespray collection.

## Collection Build Process

The role automatically:

1. Checks if Kubespray collection tarball exists
2. Builds collection using `ansible-galaxy collection build`
3. Installs collection to `ansible/collections/`
4. Makes all Kubespray playbooks available via collection namespace

## Dependencies

The Kubespray collection automatically installs its dependencies:

- ansible.utils (>=2.5.0)
- community.crypto (>=2.22.3)
- community.general (>=7.0.0)
- ansible.netcommon (>=5.3.0)
- ansible.posix (>=1.5.4)
- community.docker (>=3.11.0)
- kubernetes.core (>=2.4.2)

## Advantages Over Previous Approach

### Before (Shell Module):

```yaml
- name: Run Kubespray
  ansible.builtin.shell:
    cmd: |
      .venv-ansible-2.17/bin/ansible-playbook \
        -i {{ inventory }} \
        cluster.yml
```

❌ Requires separate Python venv  
❌ Shell module complexity  
❌ Harder to debug  
❌ Role path resolution issues  

### Now (Collection):

```yaml
- name: Deploy Cluster
  import_playbook: kubernetes_sigs.kubespray.cluster
```

✅ Native Ansible integration  
✅ Clean, simple syntax  
✅ Better error reporting  
✅ Automatic path resolution  

## Troubleshooting

### Collection not found

```bash
# Verify collection is installed
ls -la ansible/collections/ansible_collections/kubernetes_sigs/kubespray/

# Reinstall if needed
cd build/3rd-party/kubespray/kubespray-src
uv run ansible-galaxy collection build --force
uv run ansible-galaxy collection install \
  kubernetes_sigs-kubespray-2.29.0.tar.gz \
  -p ../../ansible/collections \
  --force
```

### Import playbook fails

Ensure `ANSIBLE_COLLECTIONS_PATH` is set:

```bash
export ANSIBLE_COLLECTIONS_PATH=ansible/collections
ansible-playbook ansible/playbooks/deploy-cloud-k8s.yml -i <inventory>
```

## References

- [Kubespray Documentation](https://kubespray.io/)
- [Kubespray as Ansible Collection](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/ansible/ansible_collection.md)
- [Ansible Collections Guide](https://docs.ansible.com/ansible/latest/user_guide/collections_using.html)
