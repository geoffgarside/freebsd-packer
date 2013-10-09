#!/bin/sh

# VMware Fusion specific items
pkg install -y open-vm-tools-nox11

cat <<EOF >> /etc/rc.conf

# VMware configuration
vmware_guestd_enable="YES"
vmware_guest_vmmemctl_enable="YES"
vmware_guest_vmblock_enable="YES"
vmware_guest_vmxnet_enable="YES"
vmware_guest_vmhgfs_enable="YES"
EOF

exit
