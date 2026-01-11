# Ansible Playbook - Rocky Linux 9 Nginx Setup

This Ansible playbook automates the setup of a secure nginx web server on Rocky Linux 9 with security hardening.

## Prerequisites

- **Control Node** (your machine):
  - Ansible installed (version 2.9 or higher)
  - SSH access to the target server
  - SSH private key loaded in your SSH agent or available at `~/.ssh/id_rsa`

- **Target Server**:
  - Rocky Linux 9
  - IP: 192.168.64.6
  - User: nkrgovic (with sudo privileges)
  - Python 3 installed

## Features

This playbook will:

1. Install nginx (stable version) using dnf
2. Ensure SELinux is enabled and set to enforcing mode
3. Add `noexec` mount option to `/var` and `/tmp` partitions for security
4. Install and configure firewalld
5. Configure firewalld to use nftables backend
6. Allow SSH, HTTP, and HTTPS services through the firewall
7. Create `/var/www/html/storage` directory with proper ownership
8. Set SELinux context `httpd_sys_rw_content_t` for the storage directory

## Installation

### 1. Install Required Ansible Collections

Before running the playbook, install the required Ansible collections:

```bash
ansible-galaxy collection install ansible.posix
ansible-galaxy collection install community.general
```

### 2. Verify Inventory

The [inventory.ini](inventory.ini) file contains the target server information:

```ini
[rocky_servers]
rocky9-server ansible_host=192.168.64.6 ansible_user=nkrgovic

[rocky_servers:vars]
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3
```

**Note**: If your SSH key is in a different location, update the `ansible_ssh_private_key_file` variable.

### 3. Test Connectivity

Verify Ansible can connect to the target server:

```bash
ansible rocky_servers -i inventory.ini -m ping
```

Expected output:
```
rocky9-server | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

## Usage

### Run the Playbook

Execute the playbook with:

```bash
ansible-playbook -i inventory.ini setup-nginx.yml
```

### Run with Verbose Output

For detailed execution information:

```bash
ansible-playbook -i inventory.ini setup-nginx.yml -v
```

Use `-vv` or `-vvv` for even more verbosity.

### Dry Run (Check Mode)

To see what changes would be made without applying them:

```bash
ansible-playbook -i inventory.ini setup-nginx.yml --check
```

## Post-Installation

### Verify Services

After the playbook completes, verify the services are running:

```bash
# Check nginx status
ansible rocky_servers -i inventory.ini -m shell -a "systemctl status nginx" -b

# Check firewalld status
ansible rocky_servers -i inventory.ini -m shell -a "systemctl status firewalld" -b

# Check SELinux status
ansible rocky_servers -i inventory.ini -m shell -a "getenforce" -b
```

### Verify Firewall Rules

Check that the firewall rules are active:

```bash
ansible rocky_servers -i inventory.ini -m shell -a "firewall-cmd --list-services" -b
```

Expected output should include: `ssh http https`

### Verify SELinux Context

Check the SELinux context on the storage directory:

```bash
ansible rocky_servers -i inventory.ini -m shell -a "ls -ldZ /var/www/html/storage" -b
```

Expected output should show `httpd_sys_rw_content_t` as the SELinux type.

### Verify Mount Options

Check that noexec is applied to /var and /tmp:

```bash
ansible rocky_servers -i inventory.ini -m shell -a "mount | grep -E '(\/var|\/tmp)'" -b
```

Look for `noexec` in the mount options.

## Important Notes

### SELinux
- The playbook ensures SELinux is in enforcing mode
- If SELinux mode changes, a reboot may be required
- The storage directory is set with `httpd_sys_rw_content_t` context to allow nginx read/write access

### Mount Options
- The `noexec` option prevents execution of binaries from `/var` and `/tmp`
- If `/tmp` is not a separate mount point, the playbook creates a tmpfs mount with security options
- If `/var` is not a separate partition, the noexec task will be skipped

### Firewall
- Firewalld is configured to use the nftables backend
- Only SSH, HTTP, and HTTPS services are allowed
- Changes are made permanent and applied immediately

### Nginx
- Nginx is installed from the default Rocky Linux repositories
- The service is enabled to start on boot
- Default configuration files are not modified by this playbook

## Troubleshooting

### SSH Connection Issues

If you encounter SSH connection problems:

1. Verify SSH key path is correct in [inventory.ini](inventory.ini)
2. Ensure the key has proper permissions: `chmod 600 ~/.ssh/id_rsa`
3. Test manual SSH: `ssh nkrgovic@192.168.64.6`

### Permission Denied

If you get sudo permission errors:

```bash
# Run playbook with --ask-become-pass to enter sudo password
ansible-playbook -i inventory.ini setup-nginx.yml --ask-become-pass
```

### SELinux Issues

If SELinux prevents nginx from accessing files:

```bash
# Check for SELinux denials
ansible rocky_servers -i inventory.ini -m shell -a "ausearch -m avc -ts recent" -b
```

### SELinux Python Library Missing

If you see errors about missing `libselinux-python`:

```
Failed to import the required Python library (libselinux-python)
```

This is already handled by the playbook - it installs `python3-libselinux` and `python3-policycoreutils` automatically. If you still encounter this error, you can manually install it:

```bash
ansible rocky_servers -i inventory.ini -m dnf -a "name=python3-libselinux,python3-policycoreutils state=present" -b
```

### Collection Not Found

If you see errors about missing collections:

```bash
# Install required collections
ansible-galaxy collection install ansible.posix community.general
```

## File Structure

```
.
├── setup-nginx.yml    # Main playbook
├── inventory.ini      # Inventory file with server details
└── README.md         # This file
```

## Customization

### Adding More Servers

Edit [inventory.ini](inventory.ini) and add more servers under the `[rocky_servers]` group:

```ini
[rocky_servers]
rocky9-server ansible_host=192.168.64.6 ansible_user=nkrgovic
rocky9-server2 ansible_host=192.168.64.7 ansible_user=nkrgovic
```

### Changing Firewall Rules

Modify the firewall tasks in [setup-nginx.yml](setup-nginx.yml) to add or remove services:

```yaml
- name: Allow custom service through firewalld
  ansible.posix.firewalld:
    service: custom-service
    permanent: yes
    state: enabled
    immediate: yes
```

### Modifying SELinux Contexts

Add additional SELinux context tasks as needed:

```yaml
- name: Set custom SELinux context
  community.general.sefcontext:
    target: '/path/to/directory(/.*)?'
    setype: custom_context_t
    state: present
```

## Security Considerations

1. **SELinux**: Enforcing mode provides mandatory access control
2. **noexec mounts**: Prevents execution of potentially malicious binaries
3. **Firewall**: Restricts network access to only required services
4. **nftables**: Modern firewall backend with better performance
5. **Principle of least privilege**: Nginx runs as its own user with minimal permissions

## License

This playbook is provided as-is for educational and operational purposes.

## Support

For issues or questions, please review the Troubleshooting section above or consult the official documentation:
- [Ansible Documentation](https://docs.ansible.com/)
- [Rocky Linux Documentation](https://docs.rockylinux.org/)
- [Nginx Documentation](https://nginx.org/en/docs/)
