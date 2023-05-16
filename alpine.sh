#!/bin/sh -e

echo "本脚本会抹掉 VPS 的所有数据！！"
read -rp "请确认是否安装 [Y/N]：" yesno
[[ $yesno =~ N|n ]] && exit 1

server=http://images.linuxcontainers.org
path=$(wget -O- ${server}/meta/1.0/index-system | \
grep -v edge | awk '-F;' '($1=="alpine" && $3=="amd64") {print $NF}' | tail -1)

cd /
mkdir /x
wget ${server}/${path}/rootfs.tar.xz
tar -C /x -xf rootfs.tar.xz
 
sed -i '/getty/d' /x/etc/inittab
sed -i 's/rc_sys="lxc"/rc_sys="openvz"/' /x/etc/rc.conf

# save root password and ssh directory
sed -i '/^root:/d' /x/etc/shadow
grep '^root:' /etc/shadow >> /x/etc/shadow
[ -d /root/.ssh ] && cp -a /root/.ssh /x/root/

# save network configuration
dev=$(awk 'BEGIN {max = 0} {if ($2+0 > max+0) {max=$2 ;content=$0} } END {print $1}' /proc/net/dev | sed "s/://")
ip=$(ip addr show dev $dev | grep global | awk '($1=="inet") {print $2}' | cut -d/ -f1 | head -1)
hostname=$(hostname)
 
cat > /x/etc/network/interfaces << EOF
auto lo
iface lo inet loopback
 
auto $dev
iface $dev inet static
address $ip
netmask 255.255.255.255
up ip route add default dev $dev
 
hostname $hostname
EOF
cp /etc/resolv.conf /x/etc/resolv.conf
 
# remove all old files and replace with alpine rootfs
find / \( ! -path '/dev/*' -and ! -path '/proc/*' -and ! -path '/sys/*' -and ! -path '/x/*' \) -delete || true
 
/x/lib/ld-musl-x86_64.so.1 /x/bin/busybox cp -a /x/* /
export PATH="/usr/sbin:/usr/bin:/sbin:/bin"
 
rm -rf /x
 
apk update
apk add openssh bash
echo PermitRootLogin yes >> /etc/ssh/sshd_config
rc-update add sshd default
rc-update add mdev sysinit
rc-update add devfs sysinit
#sh # (for example, run `passwd`)

sync
reboot -f