#!/bin/bash
set -e

# ========== Thông tin người dùng ==========
HOSTNAME="lucifer"
USERNAME="yllin"
USERPASS="kalanka"
ROOTPASS="kalanka"

# ========== Phân vùng ổ đĩa ==========
DISK="/dev/sda"
BOOT="/dev/sda1"
ROOT="/dev/sda2"
HOME="/dev/sda3"

echo ">>> Phân vùng đĩa"
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary fat32 1MiB 513MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 513MiB 30.5GiB
parted -s "$DISK" mkpart primary ext4 30.5GiB 100%

mkfs.vfat -F32 "$BOOT"
mkfs.ext4 "$ROOT"
mkfs.ext4 "$HOME"

mount "$ROOT" /mnt/gentoo
mkdir -p /mnt/gentoo/boot /mnt/gentoo/home
mount "$BOOT" /mnt/gentoo/boot
mount "$HOME" /mnt/gentoo/home

echo ">>> Tải và giải nén stage3"
cd /mnt/gentoo
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64/stage3-amd64-*.tar.xz
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

# ========== Cấu hình make.conf ==========
cat > /mnt/gentoo/etc/portage/make.conf <<EOF
CFLAGS="-march=native -O2 -pipe"
CXXFLAGS="\${CFLAGS}"
MAKEOPTS="-j$(nproc)"
USE="X alsa bluetooth branding dbus elogind gtk icu ipv6 jit mp3 nls opengl pulseaudio readline ssl udev unicode vaapi vim-syntax zlib -systemd networkmanager"
VIDEO_CARDS="intel i965"
INPUT_DEVICES="libinput"
GRUB_PLATFORMS="efi-64"
EOF

# ========== Chuẩn bị chroot ==========
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
chroot /mnt/gentoo /bin/bash <<'EOT'

source /etc/profile
export PS1="(chroot) \$PS1"

emerge-webrsync
eselect profile set default/linux/amd64/17.1/desktop
emerge --verbose --update --deep --newuse @world

echo "$HOSTNAME" > /etc/conf.d/hostname
echo "127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" > /etc/hosts

echo ">>> Cài NetworkManager (hỗ trợ Wi-Fi)"
emerge --ask net-misc/networkmanager
rc-update add NetworkManager default

echo ">>> Cài kernel"
emerge --ask sys-kernel/gentoo-sources
emerge --ask sys-kernel/genkernel
genkernel all

echo ">>> Cấu hình fstab"
echo "$BOOT  /boot   vfat    defaults,noatime  0 2
$ROOT  /       ext4    noatime            0 1
$HOME  /home   ext4    defaults,noatime   0 2" > /etc/fstab

echo ">>> Cài GRUB"
emerge --ask sys-boot/grub
grub-install --target=x86_64-efi --efi-directory=/boot
grub-mkconfig -o /boot/grub/grub.cfg

echo ">>> Mật khẩu root"
echo "root:$ROOTPASS" | chpasswd

echo ">>> User mới"
useradd -m -G wheel,audio,video,portage -s /bin/bash $USERNAME
echo "$USERNAME:$USERPASS" | chpasswd

echo ">>> sudo"
emerge --ask app-admin/sudo
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

echo ">>> Cài openrc & enable các dịch vụ"
emerge --ask sys-apps/openrc
rc-update add dbus default

EOT

echo ">>> Hoàn tất. Unmount và khởi động lại"
umount -l /mnt/gentoo/dev{/shm,/pts,}
umount -R /mnt/gentoo
reboot
