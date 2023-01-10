#! /bin/bash

vm='ltm03'
src_yaml="${vm}.yaml"
mount_dir="${vm}_ci"
kvm_boot="/var/lib/libvirt/boot"
cleanup=1
MOUNT=0

# cloud-init directory exists (for ISO creation)
test -d ${vm} || {
  mkdir -p ${vm}/openstack/latest
  echo '{"uuid": "534c4d5c-4b7d-4011-84a0-73ae2d2c2093"}' > ${vm}/openstack/latest/meta_data.json
}

# copy latest version of cloud-init yaml into place
cp -f $src_yaml ${vm}/openstack/latest/user_data

# Ensure existing ISO isn't mounted, then delete the existing ISO
if [[ -d ${vm}_ci ]]; then
  # Unmount the existing ISO if it is mounted
  mount | grep -qs ${vm}
  if [[ $? == 0 ]]; then sudo umount ${vm}_ci; rmdir ${vm}_ci; fi

  # Delete the old ISO
  test -f ${vm}.iso && rm ${vm}.iso
fi

# Create new cloud-init ISO
mkisofs -R -V config-2 -o ${vm}.iso ${vm} >/dev/null 2>&1

# Copy new cloud-init ISO into /var/lib/libvirt/boot
cp -f ${vm}.iso ${kvm_boot}

# Delete cloud-init directory structure after ISO is created (if requested)
if [[ $cleanup == 1 ]]; then rm -rf ${vm}; fi

# If requested, mount the new ISO for inspection
if [[ ${MOUNT} == 1 ]]; then 
  mkdir ${vm}_ci
  sudo mount ${vm}.iso ${vm}_ci -o loop
fi

echo

cat << EOF
virt-install \
--name=${vm} \
--vcpu=2 \
--cpu host-passthrough \
--ram=4096 \
--os-variant=centos7.0 \
--disk path=/var/lib/libvirt/f5/${vm}.qcow2,format=qcow2 \
--disk path=/var/lib/libvirt/boot/${vm}.iso,device=cdrom \
--network network=mgmt,model=virtio \
--network network=data10,model=virtio \
--network network=data20,model=virtio \
--network network=data30,model=virtio \
--graphics vnc,listen=0.0.0.0 \
--import \
--noautoconsole 

EOF
