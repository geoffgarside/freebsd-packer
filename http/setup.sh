#!/bin/sh
# FreeBSD 9.1 ZFS/Packer/Vagrant setup script.

dest="/mnt"

echo "Configuration"
echo -n "Disks for root: "
read rootdisks

echo -n "ZFS dataset [rpool]: "
read rpool

echo -n "Server hostname: "
read host

echo -n "Primary Interface: "
read int

echo -n "Network type: (DHCP/static): "
read nettype

echo -n "Admin username: "
read username

echo -n "Admin password: "
read password

ifconfig="DHCP"
routeropt="#"

kldstat | grep opensolaris.ko >/dev/null
if test $? -ne 0 ; then
  kldload /boot/kernel/opensolaris.ko >/dev/null
fi

kldstat | grep zfs.ko >/dev/null
if test $? -ne 0 ; then
  kldload /boot/kernel/zfs.ko >/dev/null
fi

disks=""
count=0

for I in $rootdisks; do
  num=$( echo ${I} | tr -c -d '0-9' )
  gpart destroy -F ${I} >/dev/null 2>&1
  gpart create -s GPT ${I} >/dev/null 2>&1
  gpart add -t freebsd-boot -l boot${num} -s 128K ${I} >/dev/null 2>&1
  gpart add -t freebsd-zfs -l disk${num} ${I} >/dev/null 2>&1
  gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 ${I} >/dev/null 2>&1

  disks="${disks}/dev/gpt/disk${num} "
  count=$( expr $count + 1 )
done

if test -z "$rpool" ; then
  rpool="rpool"
fi

if test $count -eq 1 ; then
  ztype=""
elif test $count -eq 2 ; then
  ztype="mirror"
else
  ztype="raidz"
fi

#mkdir -p /boot/zfs
echo "Creating ZFS root pool"
zpool create -f -o cachefile=/tmp/zpool.cache $rpool $ztype $disks
zpool status $rpool

echo "Configuring ZFS file system"
zfs set checksum=fletcher4                 $rpool
zfs set mountpoint=none                    $rpool
zfs set canmount=off                       $rpool
zfs set atime=off                          $rpool

zroot="${rpool}/ROOT/default"

zfs create -o canmount=off                 $rpool/ROOT
zfs create -o mountpoint=$dest             $rpool/ROOT/default
zpool set bootfs=$zroot                    $rpool

# Create file system sections
zfs create -o compression=on    -o exec=on      -o setuid=off   $zroot/tmp
chmod 1777 $dest/tmp

zfs create                                                      $zroot/usr
zfs create                                                      $zroot/usr/home
ln -s usr/home $dest/home

zfs create -o compression=lz4                   -o setuid=off   $zroot/usr/ports
zfs create -o compression=off   -o exec=off     -o setuid=off   $zroot/usr/ports/distfiles
zfs create -o compression=off   -o exec=off     -o setuid=off   $zroot/usr/ports/packages
zfs create -o compression=lz4   -o exec=off     -o setuid=off   $zroot/usr/src
zfs create -o compression=lz4 	-o exec=off     -o setuid=off   $zroot/usr/include
zfs create                                                      $zroot/usr/local
zfs create -o compression=lz4 	-o exec=off     -o setuid=off   $zroot/usr/local/include

zfs create                                                      $zroot/var
zfs create -o compression=lz4   -o exec=off     -o setuid=off   $zroot/var/crash
zfs create                      -o exec=off     -o setuid=off   $zroot/var/db
zfs create -o compression=lz4   -o exec=on      -o setuid=off   $zroot/var/db/pkg
zfs create                      -o exec=off     -o setuid=off   $zroot/var/empty
zfs create -o compression=lz4   -o exec=off     -o setuid=off   $zroot/var/log
zfs create -o compression=gzip  -o exec=off     -o setuid=off   $zroot/var/mail
zfs create                      -o exec=off     -o setuid=off   $zroot/var/run
zfs create -o compression=lz4   -o exec=on      -o setuid=off   $zroot/var/tmp
chmod 1777 $dest/var/tmp

echo "Configuring SWAP space"
zfs create -V 4G -o checksum=off -o org.freebsd:swap=on -o sync=disabled -o primarycache=none -o secondarycache=none $rpool/swap
swapon /dev/zvol/$rpool/swap

echo "Installing base system"
cd /usr/freebsd-dist
if test $? -ne 0 ; then
  exit
fi

export DESTDIR=$dest
for file in base.txz kernel.txz;
do (cat $file | tar --unlink -xpJf - -C ${DESTDIR:-/}); done

cp -Rlp $dest/boot/kernel $dest/boot/GENERIC

zfs set readonly=on $zroot/var/empty

cp /tmp/zpool.cache $dest/boot/zfs/zpool.cache

touch $dest/etc/fstab

echo "Configuring /boot/loader.conf"
cat <<EOF >$dest/boot/loader.conf
zfs_load="YES"
vfs.root.mountfrom="zfs:$zroot"
vfs.zfs.prefetch_disable=0
EOF

cat /tmp/bsdinstall_etc/resolv.conf > $dest/etc/resolv.conf

echo "Configuring /etc/rc.conf"
cat <<EOF >$dest/etc/rc.conf
# Network Settings
hostname="$host"
${routeropt}defaultrouter="$router"
ifconfig_$int="$ifconfig"

# Console Settings
keymap="us.iso"
keyrate="fast"

# Services
pf_enable="YES"
pf_rules="/etc/pf.conf"
zfs_enable="YES"
sshd_enable="YES"
usbd_enable="YES"
sendmail_enable="NONE"
ntpdate_enable="YES"
ntpd_enable="YES"

EOF

cat <<EOF >$dest/etc/ntp.conf
server 0.uk.pool.ntp.org
server 1.uk.pool.ntp.org
server 2.uk.pool.ntp.org
server 3.uk.pool.ntp.org

driftfile /var/db/ntpd.drift
restrict default ignore
EOF

tzsetup -C $dest UTC

touch $dest/etc/pf.conf

export PACKAGESITE=http://pkg.geoffgarside.co.uk/freebsd:9:x86:64
# export PACKAGESITE=http://pkgbeta.freebsd.org/freebsd:9:x86:64/latest

if test ! -x $dest/usr/local/sbin/pkg ; then
  fetch -o $dest/tmp/pkg.txz ${PACKAGESITE}/Latest/pkg.txz
  tar xf $dest/tmp/pkg.txz -C $dest/tmp -s ",/.*/,,g" "*/pkg-static"
  $dest/tmp/pkg-static -c $dest add /tmp/pkg.txz >/dev/null
  rm $dest/tmp/pkg.txz

  cat $dest/usr/local/etc/pkg.conf.sample | sed "s#^\(PACKAGESITE.*: \)\(.*\)#\1${PACKAGESITE}#" > $dest/usr/local/etc/pkg.conf
  $dest/usr/local/sbin/pkg-static -c $dest update -q -f
fi

$dest/usr/local/sbin/pkg-static -c $dest install -y sudo

mkdir -p $dest/usr/local/etc/sudoers.d
echo "$username ALL=(ALL) NOPASSWD: ALL" > $dest/usr/local/etc/sudoers.d/$username

chroot $dest pw groupadd $username -g 501
echo "$password" | chroot $dest pw useradd $username -u 501 -g 501 -Gwheel -d /usr/home/$username -s /bin/csh -m -h 0

zfs snapshot -r $zroot@install

cd /
zfs unmount -af
zfs set mountpoint=legacy $zroot
zfs set mountpoint=/tmp	  $zroot/tmp
zfs set mountpoint=/usr   $zroot/usr
zfs set mountpoint=/var   $zroot/var
zfs unmount -af

echo "Now completed"
reboot
