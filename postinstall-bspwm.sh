#!/bin/bash
set -e

USERNAME="yllin"
USERHOME="/home/$USERNAME"

# Cài display server và BSPWM stack
emerge --ask x11-base/xorg-server x11-drivers/xf86-video-intel x11-misc/lightdm x11-misc/lightdm-slick-greeter
emerge --ask x11-wm/bspwm x11-misc/sxhkd x11-terms/kitty x11-misc/polybar x11-misc/lxappearance

# Enable dịch vụ
rc-update add xdm default
echo 'DISPLAYMANAGER="lightdm"' > /etc/conf.d/xdm

# Slick greeter config
echo '[Seat:*]
greeter-session=lightdm-slick-greeter
user-session=bspwm' > /etc/lightdm/lightdm.conf

# Thêm .xinitrc và config BSPWM
su - $USERNAME -c "
mkdir -p ~/.config/bspwm ~/.config/sxhkd ~/.config/polybar
cp /usr/share/doc/bspwm-*/examples/bspwmrc ~/.config/bspwm/bspwmrc
cp /usr/share/doc/bspwm-*/examples/sxhkdrc ~/.config/sxhkd/sxhkdrc
chmod +x ~/.config/bspwm/bspwmrc
"

# Cài Nord theme & icon
git clone https://github.com/arcticicestudio/nord-gnome-terminal.git /tmp/nord
git clone https://github.com/vinceliuice/Tela-circle-icon-theme.git /tmp/tela
/tmp/tela/install.sh -a nord

# GTK theme: Nordic
git clone https://github.com/EliverLara/Nordic.git /usr/share/themes/Nordic

# Cấu hình GTK cho user
su - $USERNAME -c "
mkdir -p ~/.config/gtk-3.0
echo -e '[Settings]\ngtk-theme-name=Nordic\ngtk-icon-theme-name=Tela-circle-nord' > ~/.config/gtk-3.0/settings.ini
"

# Set wallpaper (tuỳ chọn)
su - $USERNAME -c "
mkdir -p ~/Pictures
wget -O ~/Pictures/nord-wallpaper.png https://raw.githubusercontent.com/arcticicestudio/nord-wallpapers/main/src/nord-wave.png
"

echo ">>> Hoàn tất cấu hình BSPWM + Kitty + Polybar + Nord cho user $USERNAME!"
