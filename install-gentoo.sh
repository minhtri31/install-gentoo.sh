#!/bin/bash
set -e

### === CẤU HÌNH === ###
HOSTNAME="gentoo-e7440"
USERNAME="user"
USERPASS="password"
ROOTPASS="rootpass"

### === KẾT NỐI MẠNG (Wi-Fi nếu cần) === ###
echo "[INFO] Kiểm tra kết nối mạng..."
ping -c 1 gentoo.org || { echo "[ERROR] Không có mạng"; exit 1; }

### === PHÂN VÙNG Ổ ĐĨA === ###
echo "[INFO] Phân vùng /dev/sda..."
sgdisk -Z /dev/sda
sgdisk -n 1:0:+512M -t 1:ef00 /dev/sda    # EFI
sgdisk -n 2:0:+30G  -t 2:8300 /dev/sda    # Root
sgdisk -n 3:0:0     -t 3:8300 /dev/sda    # Home

mkfs.vfat -F32 /dev/sda1
mkfs.ext4 /dev/sda2
mkfs.ext4 /dev/sda3

mount /dev/sda2 /mnt/gentoo
mkdir -p /mnt/gentoo/boot /mnt/gentoo/home
mount /dev/sda1 /mnt/gentoo/boot
mount /dev/sda3 /mnt/gentoo/home

### === TẢI STAGE3 === ###
cd /mnt/gentoo
echo "[INFO] Tải stage3..."
wget -qO stage3.tar.xz https://gentoo.osuosl.org/releases/amd64/autobuilds/$(wget -qO- https://gentoo.osuosl.org/releases/amd64/autobuilds/latest-stage3-amd64.txt | grep stage3 | cut -d/ -f1-2)/stage3-amd64-*.tar.xz
tar xpvf stage3*.tar.xz --xattrs-include='*.*' --numeric-owner

### === COPY CẤU HÌNH CHROOT === ###
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev

### === CHROOT === ###
cat << EOF | chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(gentoo-chroot) # "

echo "[INFO] Cấu hình make.conf"
sed -i 's/^COMMON_FLAGS.*/COMMON_FLAGS="-march=haswell -O2 -pipe"/' /etc/portage/make.conf
echo 'MAKEOPTS="-j4"' >> /etc/portage/make.conf

emerge-webrsync

echo "[INFO] Chọn profile"
eselect profile set 1

echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1   localhost" > /etc/hosts
echo "127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

echo "Asia/Ho_Chi_Minh" > /etc/timezone
emerge --config sys-libs/timezone-data
echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
locale-gen
eselect locale set en_US.utf8
env-update && source /etc/profile

emerge --ask --verbose sys-kernel/gentoo-sources sys-kernel/genkernel
genkernel all

emerge syslog-ng cronie dhcpcd sudo networkmanager
rc-update add syslog-ng default
rc-update add cronie default
rc-update add dhcpcd default
rc-update add NetworkManager default

echo "[INFO] Cài grub UEFI"
emerge --ask sys-boot/grub:2 efibootmgr dosfstools
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Gentoo
grub-mkconfig -o /boot/grub/grub.cfg

echo "[INFO] Đặt mật khẩu root"
echo "root:$ROOTPASS" | chpasswd

useradd -m -G users,wheel,audio,video -s /bin/bash $USERNAME
echo "$USERNAME:$USERPASS" | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers

emerge x11-base/xorg-server x11-misc/lxappearance x11-drivers/xf86-video-intel x11-terms/kitty x11-wm/bspwm x11-misc/sxhkd x11-misc/polybar x11-misc/rofi x11-misc/lightdm x11-misc/lightdm-slick-greeter media-fonts/nerd-fonts feh picom dunst

rc-update add lightdm default

EOF

echo "[✅] Cài đặt hoàn tất. Gõ 'reboot' để khởi động lại!"
