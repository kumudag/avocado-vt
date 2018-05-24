#!/bin/bash
BASEPATH=/home/kvmci
KVMCILOG=$BASEPATH/kvmci.log
EMULATORPATH=/usr/share/avocado-plugins-vt/bin/qemu
echo "KVMCI: Building Upstream Kernel..."
[ -d $BASEPATH/linux ] || (mkdir -p $BASEPATH && cd $BASEPATH && git clone https://github.com/torvalds/linux.git) >> $KVMCILOG 2>&1
cd $BASEPATH/linux && git pull >> $KVMCILOG 2>&1
wget https://raw.githubusercontent.com/sathnaga/avocado-vt/kvmci/kvmci/ppc/config_kvmppc -O .config >> $KVMCILOG 2>&1
make olddefconfig >> $KVMCILOG 2>&1
make -j 240 >> $KVMCILOG 2>&1
setenforce 0

echo "KVMCI: Installing avocado..."
[ -d $BASEPATH/avocado ] || (cd $BASEPATH && git clone https://github.com/avocado-framework/avocado.git) >> $KVMCILOG 2>&1
cd $BASEPATH/avocado && git pull >> $KVMCILOG 2>&1
make requirements >> $KVMCILOG 2>&1
python setup.py install >> $KVMCILOG 2>&1

echo "KVMCI: Installing avocado-vt..."
[ -d $BASEPATH/avocado-vt ] || (cd $BASEPATH && git clone https://github.com/sathnaga/avocado-vt.git -b kvmci) >> $KVMCILOG 2>&1
cd $BASEPATH/avocado-vt && git pull >> $KVMCILOG 2>&1
make requirements >> $KVMCILOG 2>&1
python setup.py install >> $KVMCILOG 2>&1

echo "KVMCI: Bootstrapping avocado-vt..."
yes|avocado vt-bootstrap --vt-type qemu --vt-guest-os JeOS.27.ppc64le >> $KVMCILOG 2>&1
avocado vt-bootstrap --vt-type libvirt --vt-no-downloads >> $KVMCILOG 2>&1

echo "KVMCI: Building Upstream Qemu..."
wget https://raw.githubusercontent.com/sathnaga/avocado-vt/kvmci/kvmci/ppc/qemu_build.cfg -O $BASEPATH/qemu_build.cfg >> $KVMCILOG 2>&1
avocado run --vt-config $BASEPATH/qemu_build.cfg 

echo "KVMCI: Building Upstream Libvirt..."
wget https://raw.githubusercontent.com/sathnaga/avocado-vt/kvmci/kvmci/ppc/libvirt_build.cfg -O $BASEPATH/libvirt_build.cfg >> $KVMCILOG 2>&1
avocado run --vt-config $BASEPATH/libvirt_build.cfg

echo "KVMCI: Running tests with Upstream qemu, libvirt, guest kernel..."
avocado run guestpin.with_emualorpin.sequential.positive.with_cpu_hotplug --vt-type libvirt --vt-extra-params emulator_path=$EMULATORPATH create_vm_libvirt=yes kill_vm_libvirt=yes env_cleanup=yes smp=2 take_regular_screendumps=no backup_image_before_testing=no libvirt_controller=virtio-scsi scsi_hba=virtio-scsi-pci drive_format=scsi-hd use_os_variant=no restore_image_after_testing=no vga=none display=nographic kernel=$BASEPATH/linux/vmlinux kernel_args='root=/dev/sda2 rw console=tty0 console=ttyS0,115200 init=/sbin/init initcall_debug' --vt-guest-os JeOS.27.ppc64le
