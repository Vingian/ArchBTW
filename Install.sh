#!/bin/bash

#iwctl --passphrase "" station wlan0 connect-hidden ""
#curl -OL "https://github.com/<USER>/<PROJECT>/raw/main/Install.sh"
#chmod +x Install.sh

_git='https://github.com/Vingian/ArchBTW'
User='vingian'
Password='1234'
HostName='arch'
Keyboard='br-abnt2'
Locale='pt_BR.UTF-8'
LocalTime='America/Sao_Paulo'
SwapSize='8'
KernelCMD='intel_iommu=on,igfx_off kvm.ignore_msrs=1 i915.enable_guc=2 i915.enable_fbc=0 nvidia-drm.modeset=1 drm.edid_firmware=eDP-1:edid/144.bin'
Kernel='linux-xanmod-edge-bin'
EDID="$_git/raw/main/144.bin"
WallPaper="$_git/raw/main/blue_galaxy.jpg"
RGBController="$_git/raw/main/ITE8291.c"
Mode='0'

while getopts "w:f:u:p:h:r:l:t:s:c:k:e:b:m:" opt
do
  case "$opt" in
    w ) WiFi="$OPTARG" ;;
    f ) WiFiPass="$OPTARG" ;;
    u ) User="$OPTARG" ;;
    p ) Password="$OPTARG" ;;
    h ) HostName="$OPTARG" ;;
    r ) Keyboard="$OPTARG" ;;
    l ) Locale="$OPTARG" ;;
    t ) LocalTime="$OPTARG" ;;
    s ) SwapSize="$OPTARG" ;;
    c ) KernelCMD="$OPTARG" ;;
    k ) Kernel="$OPTARG" ;;
    e ) EDID="$OPTARG" ;;
    b ) WallPaper="$OPTARG" ;;
    m ) Mode="$OPTARG" ;;
  esac
done

if [ -n "$WiFi" ]
then
  if [ -z "$WiFiPass" ]
  then
    iwctl station wlan0 connect-hidden "$WiFi"
  else
    iwctl --passphrase "$WiFiPass" station wlan0 connect-hidden "$WiFi"
  fi
  sleep 10
fi

ping -c 3 '8.8.8.8' >/dev/null 2>&1
if [ "$?" != '0' ]
then
  echo 'No internet...'
  exit
fi

#sleep 0
#exec &> >(tee Install.log)

systemctl disable reflector >/dev/null 2>&1
systemctl stop reflector >/dev/null 2>&1
killall -9 reflector >/dev/null 2>&1

#echo 'Updating mirrors... (this might take some time)'
#reflector --latest 100 --sort rate --save /etc/pacman.d/mirrorlist >/dev/null 2>&1
echo 'Server = https://mirror.osbeck.com/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
echo 'Server = https://arch.mirror.constant.com/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = http://arch.mirror.constant.com/$repo/os/$arch' >> /etc/pacman.d/mirrorlist

arrKeyboard=(${Keyboard//-/ })
KeyLayout=${arrKeyboard[0]}
KeyVariant=${arrKeyboard[1]}

loadkeys $Keyboard

#### #### #### #### #### #### #### ####
nvme format -s1 -f /dev/nvme0n1 
nvme format -s1 -f /dev/nvme1n1

#parted -s -a optimal /dev/nvme0n1 mklabel gpt mkpart efi fat32 0% 100MiB mkpart linux ext4 100MiB 100% set 1 esp on
#parted -s -a optimal /dev/nvme1n1 mklabel gpt mkpart data ext4 0% 100%
BootSizeMiB="100"
SwapSizeMiB="$(expr 1024 \* $(expr $SwapSize \* 1000 + $BootSizeMiB) / 1000)"
parted -s -a optimal /dev/nvme0n1 mklabel gpt mkpart efi fat32 0% ${BootSizeMiB}MiB mkpart swap linux-swap ${BootSizeMiB}MiB ${SwapSizeMiB}MiB mkpart linux xfs ${SwapSizeMiB}MiB 100% set 1 esp on
parted -s -a optimal /dev/nvme1n1 mklabel gpt mkpart data xfs 0% 100%

mkfs.fat -F 32 /dev/nvme0n1p1
mkswap /dev/nvme0n1p2
#mkfs.ext4 -F /dev/nvme0n1p2
#mkfs.ext4 -F /dev/nvme1n1p1
mkfs.xfs -f /dev/nvme0n1p3
mkfs.xfs -f /dev/nvme1n1p1

swapon /dev/nvme0n1p2
mount /dev/nvme0n1p3 /mnt
mkdir -p /mnt/efi
mount /dev/nvme0n1p1 /mnt/efi
mkdir /mnt/data
mount /dev/nvme1n1p1 /mnt/data
chmod 777 /mnt/data

fstrim -a

#dd if=/dev/zero of=/mnt/swapfile bs=1G count=$SwapSize status=progress
#chmod 600 /mnt/swapfile
#mkswap /mnt/swapfile
#swapon /mnt/swapfile
#### #### #### #### #### #### #### ####

sed -i -z 's|#ParallelDownloads|DisableDownloadTimeout\nParallelDownloads|g' /etc/pacman.conf
sed -i -z 's|#\[multilib\]\n#|\[multilib\]\n|g' /etc/pacman.conf
pacman -Sy --needed --noconfirm archlinux-keyring

mount -o remount,size=6G /run/archiso/cowspace
pacman -Sy --needed --noconfirm base-devel git

if [ -n "$EDID" ]; then _nopatchs=1; fi
if [[ "${Kernel,,}" == *'xanmod'* && "${Kernel,,}" == *'-bin' ]]
then
  useradd -m xanmod
  su - xanmod -c "
    git clone '${_git%/*}/${Kernel}.git'
    pushd '$Kernel'
    _nopatchs='$_nopatchs' makepkg -d
    mv *.zst ../
    popd
    git clone '${_git%/*}/${Kernel}-headers.git'
    pushd '${Kernel}-headers'
    makepkg -d
    mv *.zst ../
    popd
  "
  mv /home/xanmod/*.zst /root/
  userdel -r xanmod >/dev/null 2>&1
fi

cp /etc/pacman.conf ./aur1.conf
pacman-key --recv-key FBA220DFC880C036 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key FBA220DFC880C036
pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" >> aur1.conf

pacstrap /mnt base linux-firmware sof-firmware intel-ucode xfsprogs sudo nano grub efibootmgr initramfs pahole dkms
if [ -n "$Kernel" ]
then
  if [[ "${Kernel,,}" == *'xanmod'* ]]
  then
    if ls linux-*.zst &>/dev/null
    then
      pacstrap -U /mnt *.zst
    else
      pacstrap -C aur1.conf /mnt $Kernel ${Kernel}-headers

      #cp /etc/pacman.conf ./aur2.conf
      #echo -e "\n[archlinuxcn]\nServer = https://mirror.xtom.com/archlinuxcn/\$arch" >> aur2.conf
      #pacman -Sy --config aur2.conf --noconfirm archlinuxcn-keyring

      #pacstrap -C aur2.conf /mnt $Kernel ${Kernel}-headers
    fi
  else
    if [[ "${Kernel,,}" == *'mainline' ]]
    then
      cp /etc/pacman.conf ./aur3.conf
      pacman-key --recv-keys 313F5ABD
      pacman-key --lsign-key 313F5ABD
      echo -e "\n[miffe]\nServer = http://arch.miffe.org/\$arch/" >> aur3.conf

      pacstrap -C aur3.conf /mnt $Kernel ${Kernel}-headers
    else
      pacstrap -C aur1.conf /mnt $Kernel ${Kernel}-headers
    fi
  fi
else
  pacstrap /mnt linux linux-headers
fi

genfstab -U /mnt >> /mnt/etc/fstab

if [ -n "$EDID" ]
then
  curl -OL "$EDID"
  mkdir -p /mnt/usr/lib/firmware/edid
  mv *.bin /mnt/usr/lib/firmware/edid/
fi

if [ "$Mode" == '0' ]
then
  LangLocale='en_US.UTF-8'
  LangTexts=('Run in Terminal' 'Search')
  Packages='kdenlive'
  Packages="$Packages qemu virt-manager dnsmasq edk2-ovmf swtpm"
  Packages="$Packages base-devel bc git mingw-w64-gcc codeblocks"
  Packages2=''
read -r -d '' XCMD <<- EOM
usermod -a -G libvirt $User
sed -i 's|#user\s*=\s*.*|user = "'"$User"'"|g' /etc/libvirt/qemu.conf
sed -i 's|#group\s*=\s*.*|group = "libvirt"|g' /etc/libvirt/qemu.conf
systemctl enable libvirtd >/dev/null 2>&1
EOM
else
  LangLocale="$Locale"
  LangTexts=('Rodar no Terminal' 'Buscar')
  Packages='avidemux-qt wget'
  Packages2='jdownloader2'
  XCMD=''
fi

cat <<CFG > /mnt/Config.sh
#!/bin/bash

ln -sf "/usr/share/zoneinfo/$LocalTime" /etc/localtime
hwclock --systohc

sed -i 's|#en_US.UTF-8 |en_US.UTF-8 |g' /etc/locale.gen
sed -i 's|#'"$Locale"' |'"$Locale"' |g' /etc/locale.gen
sed -i 's|^\(am_pm\s\+\)"";""|\1"am";"pm"|g' /usr/share/i18n/locales/${Locale%%.*}
sed -i 's|^\(t_fmt_ampm\s\+\)""|\1"%H:%M"|g' /usr/share/i18n/locales/${Locale%%.*}
locale-gen
echo "LANG=$LangLocale" > /etc/locale.conf
echo "LC_NUMERIC=$Locale" >> /etc/locale.conf
echo "LC_TIME=$Locale" >> /etc/locale.conf
echo "LC_MONETARY=$Locale" >> /etc/locale.conf
echo "LC_PAPER=$Locale" >> /etc/locale.conf
echo "LC_NAME=$Locale" >> /etc/locale.conf
echo "LC_ADDRESS=$Locale" >> /etc/locale.conf
echo "LC_TELEPHONE=$Locale" >> /etc/locale.conf
echo "LC_MEASUREMENT=$Locale" >> /etc/locale.conf
echo "LC_IDENTIFICATION=$Locale" >> /etc/locale.conf
echo "KEYMAP=$Keyboard" > /etc/vconsole.conf

echo "$HostName" > /etc/hostname
echo -e "127.0.0.1    localhost\n::1          localhost\n127.0.1.1    $HostName.localdomain    $HostName" >> /etc/hosts

useradd -m -G wheel,audio,video,input,kvm -c "${User^}" $User
echo "$User:$Password" | chpasswd
echo "root:$Password" | chpasswd

sed 's|#\s*%wheel ALL=(ALL:ALL) ALL|%wheel ALL=(ALL:ALL) ALL|g' /etc/sudoers > /etc/sudoers.new
EDITOR='cp /etc/sudoers.new' visudo
rm /etc/sudoers.new

sed -i 's|#\s*sign_file\s*=.*|sign_file='\''/usr/lib/modules/\${kernelver}/build/scripts/sign-file'\''|g' /etc/dkms/framework.conf

grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/efi
sed -i 's|GRUB_TIMEOUT\s*=\s*.*|GRUB_TIMEOUT=0|g' /etc/default/grub
if [ -n "$KernelCMD" ]
then
  sed -i 's|GRUB_CMDLINE_LINUX_DEFAULT\s*=\s*"\(.*\)"|GRUB_CMDLINE_LINUX_DEFAULT="\1 '"$KernelCMD"'"|g' /etc/default/grub
fi
grub-mkconfig -o /boot/grub/grub.cfg
CFG

chmod +x /mnt/Config.sh
arch-chroot /mnt ./Config.sh
rm /mnt/Config.sh

#xf86-video-intel
#gdm gnome-shell gnome-control-center gnome-tweaks gnome-terminal nautilus xdg-user-dirs gedit gnome-calculator
pacstrap /mnt --needed libusb-compat usb_modeswitch smartmontools nvme-cli ntfs-3g hdparm zsh grml-zsh-config irqbalance thermald \
  xorg xf86-input-synaptics lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings xfce4 xfce4-goodies xdg-user-dirs galculator \
  gvfs gvfs-smb gvfs-mtp sshfs catfish \
  networkmanager network-manager-applet networkmanager-openvpn \
  realtime-privileges wireplumber pipewire-alsa pipewire-pulse pipewire-jack pavucontrol \
  bluez bluez-utils blueman \
  vulkan-intel intel-media-driver intel-gpu-tools \
  nvidia-dkms nvidia-utils lib32-nvidia-utils opencl-nvidia lib32-opencl-nvidia nvidia-settings nvidia-prime \
  mesa lib32-mesa mesa-utils vulkan-icd-loader lib32-vulkan-icd-loader vulkan-tools libva-utils \
  ttf-roboto ttf-liberation noto-fonts noto-fonts-cjk noto-fonts-emoji terminus-font breeze \
  p7zip zip unzip unrar xarchiver \
  java-runtime java-environment=8 \
  neofetch htop gparted mediainfo-gui vlc obs-studio audacity fdkaac gimp steam firefox transmission-gtk flatpak $Packages \
  gtk-engines gtk-engine-murrine metacity protobuf spdlog lib32-dbus
pacstrap -U /mnt 'https://archive.archlinux.org/packages/p/protobuf/protobuf-3.20.1-2-x86_64.pkg.tar.zst'
yes | pacstrap -C aur1.conf -i /mnt --needed ttf-ms-fonts qogir-gtk-theme-git qogir-icon-theme-git compiz xfce4-panel-compiz mangohud lib32-mangohud $Packages2

cat <<COD > i915paranoid.c
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char* argv[])
{
	int x=argc>1?atoi(argv[1]):0;
	setuid(0);
	system(x?"sysctl -w dev.i915.perf_stream_paranoid=1":"sysctl -w dev.i915.perf_stream_paranoid=0");
	return 0;
}
COD
gcc -O2 i915paranoid.c -o i915paranoid
chmod u+s i915paranoid
mv i915paranoid /mnt/usr/bin/

if [ -n "$WallPaper" ]
then
  curl -OL "$WallPaper"
  mv *.jpg *.png /mnt/usr/share/backgrounds/
fi

if [ -n "$RGBController" ]
then
  curl -L "$RGBController" -o RGBController.c
  gcc -O2 RGBController.c -o RGBController
  chmod u+s RGBController
  mv RGBController /mnt/usr/bin/
cat <<SVC > /mnt/etc/systemd/system/RGBController.service
[Unit]
Description=Initialize RGB Controller

[Service]
ExecStart=/usr/bin/RGBController

[Install]
WantedBy=multi-user.target
SVC
fi

cat <<CFG > /mnt/Config.sh
#!/bin/bash

cat <<XPR > /etc/xprofile
#!/bin/bash
xrandr --newmode "1920x1080_165.00"  525.00  1920 2088 2296 2672  1080 1083 1088 1192 -hsync +vsync
xrandr --addmode eDP-1 1920x1080_165.00
xrandr --newmode "1600x900_165.00"  364.25  1600 1736 1912 2224  900 903 908 994 -hsync +vsync
xrandr --addmode eDP-1 1600x900_165.00
xrandr --newmode "1280x720_165.00"  230.75  1280 1384 1520 1760  720 723 728 796 -hsync +vsync
xrandr --addmode eDP-1 1280x720_165.00
XPR
chmod +x /etc/xprofile

mkdir -p /etc/X11/xorg.conf.d
cat <<XOR > /etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
  Identifier "Keyboard Default"
  MatchIsKeyboard "yes"
  Option "XkbLayout" "$KeyLayout"
  Option "XkbVariant" "$KeyVariant"
EndSection
XOR

cat <<XOR > /etc/X11/xorg.conf.d/00-mouse.conf
Section "InputClass"
  Identifier "Mouse Default"
  Driver "libinput"
  MatchIsPointer "yes"
  Option "AccelProfile" "flat"
  Option "AccelSpeed" "0"
EndSection
XOR

cat <<XOR > /etc/X11/xorg.conf.d/00-intel.conf
Section "Device"
  Identifier "Intel Graphics"
  Driver "modesetting"
  #Driver "intel"
  #Option "VSync" "false"
  #Option "TearFree" "false"
  #Option "TripleBuffer" "false"
EndSection
XOR

cat <<XOR > /etc/X11/xorg.conf.d/10-nvidia.conf
Section "Device"
  Identifier "NVIDIA Card"
  Driver "nvidia"
  BusID "PCI:1:0:0"
EndSection
XOR

cat <<XDG > /etc/xdg/autostart/i915paranoid.desktop
[Desktop Entry]
Type=Application
Exec=i915paranoid
Name=i915 Paranoid
XDG

mkdir -p /etc/dconf/profile
echo -e "user-db:user\nsystem-db:local" > /etc/dconf/profile/user
mkdir -p /etc/dconf/db/local.d
echo -e "[org/gnome/desktop/interface]\ngtk-theme='Qogir-Dark'\nicon-theme='Qogir-dark'\ncolor-scheme='prefer-dark'\n" > /etc/dconf/db/local.d/compiz
echo -e "[org/gnome/desktop/wm/preferences]\ntheme='Qogir-Dark'\nbutton-layout='appmenu:minimize,maximize,close'\n" >> /etc/dconf/db/local.d/compiz
echo -e "[org/gnome/desktop/peripherals/mouse]\naccel-profile='flat'\n" >> /etc/dconf/db/local.d/compiz
dconf update

sed -i 's|use_compositing=true|use_compositing=false|g' /usr/share/xfwm4/defaults
sed -i 's|name="ThemeName" type="string" value="Adwaita"|name="ThemeName" type="string" value="Qogir-Dark"|g' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
sed -i 's|name="IconThemeName" type="string" value="Adwaita"|name="IconThemeName" type="string" value="Qogir-dark"|g' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
sed -i 's|"xfwm4"|"compiz"|g' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml

sed -i 's|.*</actions>.*||g' /etc/xdg/Thunar/uca.xml
cat <<XDG >> /etc/xdg/Thunar/uca.xml
  <action>
    <icon>application-x-shellscript</icon>
    <name>${LangTexts[0]}</name>
    <command>xfce4-terminal -e &quot;%f&quot;</command>
    <description></description>
    <patterns>*</patterns>
    <other-files/>
  </action>

  <action>
    <icon>searching</icon>
    <name>${LangTexts[1]}</name>
    <command>catfish %f</command>
    <description></description>
    <patterns>*</patterns>
    <directories/>
    <audio-files/>
    <image-files/>
    <other-files/>
    <text-files/>
    <video-files/>
  </action>

  <action>
    <icon>mediainfo</icon>
    <name>Media Info</name>
    <command>mediainfo-gui %f</command>
    <description></description>
    <patterns>*</patterns>
    <audio-files/>
    <image-files/>
    <video-files/>
  </action>

XDG
echo '</actions>' >> /etc/xdg/Thunar/uca.xml

sed -i 's|.*\s--ensure-directory\s.*|\tif \[ \$# -gt 1 \]; then\n\t\texec xarchiver --multi-extract "\$@"\n\telse\n\t\texec xarchiver --ensure-directory "\$@"\n\tfi|g' /usr/lib/xfce4/thunar-archive-plugin/xarchiver.tap
sed -i 's|.*\s--extract\s.*|\tif \[ \$# -gt 1 \]; then\n\t\texec xarchiver --multi-extract "\$@"\n\telse\n\t\texec xarchiver --extract "\$@"\n\tfi|g' /usr/lib/xfce4/thunar-archive-plugin/xarchiver.tap

sed -i '/MimeType/d' /usr/share/applications/org.xfce.Catfish.desktop
sed -i '/MimeType/d' /usr/share/applications/mediainfo-gui.desktop
update-desktop-database --quiet

usermod -a -G realtime $User

mkdir -p /etc/pipewire
cp /usr/share/pipewire/pipewire-pulse.conf /etc/pipewire/
sed -i 's|#channelmix\.upmix\s.*|channelmix\.upmix = false|g' /etc/pipewire/pipewire-pulse.conf
sed -i 's|#channelmix\.upmix-method\s.*|channelmix\.upmix-method = simple|g' /etc/pipewire/pipewire-pulse.conf
sed -i 's|#channelmix\.lfe-cutoff\s.*|channelmix\.lfe-cutoff = 0|g' /etc/pipewire/pipewire-pulse.conf
sed -i 's|#channelmix\.fc-cutoff\s.*|channelmix\.fc-cutoff = 0|g' /etc/pipewire/pipewire-pulse.conf
sed -i 's|#channelmix\.stereo-widen\s.*|channelmix\.stereo-widen = 0|g' /etc/pipewire/pipewire-pulse.conf

echo "LIBGL_DRI3_DISABLE=1" >> /etc/environment
echo "PROTON_NO_FSYNC=1" >> /etc/environment
echo "PROTON_NO_WRITE_WATCH=1" >> /etc/environment
echo "PROTON_HEAP_DELAY_FREE=1" >> /etc/environment
echo "PROTON_HIDE_NVIDIA_GPU=1" >> /etc/environment

$XCMD

systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1
systemctl enable fstrim.timer irqbalance thermald lightdm NetworkManager bluetooth >/dev/null 2>&1
#systemctl enable fstrim.timer irqbalance thermald gdm NetworkManager bluetooth >/dev/null 2>&1

if [ -n "$RGBController" ]
then
  systemctl enable RGBController
fi

mkdir -p /etc/xdg/xfce4/kiosk
echo -e "[xfce4-session]\nSaveSession=NONE\n" > /etc/xdg/xfce4/kiosk/kioskrc

chsh -s /usr/bin/zsh
chsh -s /usr/bin/zsh "$User"
CFG

chmod +x /mnt/Config.sh
arch-chroot /mnt ./Config.sh
rm /mnt/Config.sh

#chmod 666 Install.log
#cp Install.log "/mnt/home/$User/"

#### #### #### #### #### #### #### ####
#swapoff /mnt/swapfile
swapoff /dev/nvme0n1p2
#### #### #### #### #### #### #### ####

umount -R /mnt

while true
do
  read -p "Reboot?[yN] " yn
  case $yn in
    [Yy]* ) reboot ;;
    * ) break ;;
  esac
done
