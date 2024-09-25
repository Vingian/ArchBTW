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
WiFiDom='BR'
SwapSize='8'
zramSwapSize=$(($(free --giga | awk '/^Mem:/{print $2}') / 4 * 2))
KernelCMD='consoleblank=3600 threadirqs intel_iommu=on,igfx_off iommu=pt split_lock_detect=off kvm.ignore_msrs=1 kvm.report_ignored_msrs=0 i915.enable_guc=3 i915.enable_fbc=0 nvidia-drm.modeset=1 nvidia.NVreg_UsePageAttributeTable=1 nvidia.NVreg_InitializeSystemMemoryAllocations=0 nvidia.NVreg_EnableStreamMemOPs=1 nvidia.NVreg_EnableResizableBar=1'
Kernel='linux-cachyos-bore'
WallPaper="$_git/raw/main/blue_galaxy.jpg"
RGBController="${_git%/*}/ITE8291/raw/main/ITE8291.c"
Mode='0'
FormatAll=false

while getopts "w:f:u:p:h:r:l:t:s:z:c:k:b:m:a" opt
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
    z ) zramSwapSize="$OPTARG" ;;
    c ) KernelCMD="$OPTARG" ;;
    k ) Kernel="$OPTARG" ;;
    b ) WallPaper="$OPTARG" ;;
    m ) Mode="$OPTARG" ;;
    a ) FormatAll=true ;;
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

echo 'Synchronizing time...'
while :
do
  timedatectl set-ntp true
  sleep 3
  timedatectl set-ntp false
  if timedatectl status | grep -q 'synchronized: yes'
  then
    echo 'Time synchronized!'
    break
  fi
  if ((c++)) && ((c==10))
  then
    echo 'Time synchronization failed...'
    exit
  fi
done
unset c

#sleep 0
#exec &> >(tee Install.log)

systemctl disable reflector >/dev/null 2>&1
systemctl stop reflector >/dev/null 2>&1
killall -9 reflector >/dev/null 2>&1

#echo 'Updating mirrors... (this might take some time)'
#reflector --latest 100 --sort rate --threads 10 --save /etc/pacman.d/mirrorlist >/dev/null 2>&1
echo 'Server = https://forksystems.mm.fcix.net/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
echo 'Server = https://coresite.mm.fcix.net/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = https://mirror.fcix.net/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = https://mirrors.xtom.com/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = https://arch.mirror.constant.com/$repo/os/$arch' >> /etc/pacman.d/mirrorlist

arrKeyboard=(${Keyboard//-/ })
KeyLayout=${arrKeyboard[0]}
KeyVariant=${arrKeyboard[1]}

loadkeys $Keyboard

sed -i 's|#Color|Color|g' /etc/pacman.conf
sed -i -z 's|#ParallelDownloads|DisableDownloadTimeout\nParallelDownloads|g' /etc/pacman.conf
sed -i -z 's|#\[multilib\]\n#|\[multilib\]\n|g' /etc/pacman.conf
cp /etc/pacman.conf pacman.conf.tmp
pacman -Sy --needed --noconfirm archlinux-keyring

#### #### #### #### #### #### #### ####
[ ! -e /dev/nvme0n1 -o ! -e /dev/nvme1n1 ] && echo 'NVME check failed...' && exit
pacman -U --noconfirm https://archive.archlinux.org/packages/x/xfsprogs/xfsprogs-6.4.0-1-x86_64.pkg.tar.zst

nvme format -s1 -f /dev/nvme0n1 
[ "$FormatAll" = true ] && nvme format -s1 -f /dev/nvme1n1

BootSizeMiB='100'
SwapSizeMiB=$(($SwapSize * 1024 + $BootSizeMiB))
#parted -s -a optimal /dev/nvme0n1 mklabel gpt mkpart efi fat32 0% ${BootSizeMiB}MiB mkpart swap linux-swap ${BootSizeMiB}MiB ${SwapSizeMiB}MiB mkpart linux xfs ${SwapSizeMiB}MiB 100% set 1 esp on
parted -s -a optimal /dev/nvme0n1 mklabel gpt mkpart efi fat32 0% ${BootSizeMiB}MiB mkpart linux xfs ${BootSizeMiB}MiB 100% set 1 esp on
[ "$FormatAll" = true ] && parted -s -a optimal /dev/nvme1n1 mklabel gpt mkpart data xfs 0% 100%

mkfs.fat -F 32 /dev/nvme0n1p1
#mkswap /dev/nvme0n1p2
#mkfs.xfs -f /dev/nvme0n1p3
mkfs.xfs -f /dev/nvme0n1p2
[ "$FormatAll" = true ] && mkfs.xfs -f /dev/nvme1n1p1

#swapon /dev/nvme0n1p2
#mount /dev/nvme0n1p3 /mnt -o noatime
mount /dev/nvme0n1p2 /mnt -o noatime
mkdir /mnt/efi
mount /dev/nvme0n1p1 /mnt/efi -o noatime
mkdir /mnt/data
mount /dev/nvme1n1p1 /mnt/data -o noatime
chmod 777 /mnt/data

fstrim -a

mkswap -U clear --size ${SwapSize}G --file /mnt/swapfile
swapon /mnt/swapfile
#### #### #### #### #### #### #### ####

mount -o remount,size=6G /run/archiso/cowspace
pacman -Sy --needed --noconfirm base-devel git

if [[ "${Kernel,,}" == *'xanmod'* && "${Kernel,,}" == *'-bin' ]]
then
  useradd -m xanmod
  su - xanmod -c "
    git clone '${_git%/*}/${Kernel}.git'
    pushd '$Kernel'
    makepkg -d
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

cp pacman.conf.tmp chaotic.conf
pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
pacman-key --lsign-key 3056513887B78AEB
echo -e "\n[chaotic-aur]\nServer = https://cdn-mirror.chaotic.cx/\$repo/\$arch" >> chaotic.conf
pacman -Sy --config chaotic.conf --noconfirm chaotic-keyring

pacstrap /mnt --needed base linux-firmware sof-firmware intel-ucode xfsprogs sudo nano grub efibootmgr initramfs pahole dkms
[ -f chaotic.conf ] && yes '' | pacstrap -C chaotic.conf -i /mnt --needed upd72020x-fw
if [ -n "$Kernel" ]
then
  if [[ "${Kernel,,}" == *'xanmod'* ]]
  then
    if ls linux-*.zst &>/dev/null
    then
      pacstrap -U /mnt *.zst
    else
      pacstrap -C chaotic.conf /mnt $Kernel ${Kernel}-headers
    fi
  elif [[ "${Kernel,,}" == *'lqx'* ]]
  then
    cp pacman.conf.tmp lqx.conf
    pacman-key --recv-key 9AE4078033F8024D --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 9AE4078033F8024D
    echo -e "\n[liquorix]\nServer = https://liquorix.net/archlinux/\$repo/\$arch" >> lqx.conf

    pacstrap -C lqx.conf /mnt $Kernel ${Kernel}-headers
  elif [[ "${Kernel,,}" == *'cachyos'* ]]
  then
    cp pacman.conf.tmp cachy.conf
    sed -i -z 's|\n\[core\]\n|\n#\[core\]\n#|g' cachy.conf
    sed -i -z 's|\n\[extra\]\n|\n#\[extra\]\n#|g' cachy.conf
    sed -i -z 's|\n\[multilib\]\n|\n#\[multilib\]\n#|g' cachy.conf
    pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key F3B607488DB35A47
    echo -e "\n[cachyos-v4]\nServer = https://mirror.cachyos.org/repo/\$arch/\$repo" >> cachy.conf

    pacstrap -C cachy.conf -D /mnt --arch x86_64_v4 $Kernel ${Kernel}-headers
  else
    pacstrap -C chaotic.conf /mnt $Kernel ${Kernel}-headers
  fi
else
  pacstrap /mnt linux linux-headers
fi

genfstab -U /mnt >> /mnt/etc/fstab

if [ "$Mode" = '0' ]
then
  LangLocale='en_US.UTF-8'
  LangTexts=('Run in Terminal' 'Search')
  Packages='kdenlive'
  Packages="$Packages qemu-desktop virt-manager edk2-ovmf swtpm"
  Packages="$Packages base-devel bc git mingw-w64-gcc codeblocks"
  Packages2=''
read -r -d '' XCMD <<- EOM
usermod -a -G libvirt $User
sed -i 's|^\s*#unix_sock_group\s*=\s*.*|unix_sock_group = "libvirt"|g' /etc/libvirt/libvirtd.conf
sed -i 's|^\s*#unix_sock_rw_perms\s*=\s*.*|unix_sock_rw_perms = "0770"|g' /etc/libvirt/libvirtd.conf
sed -i 's|^\s*#user\s*=\s*.*|user = "'"$User"'"|g' /etc/libvirt/qemu.conf
sed -i 's|^\s*#group\s*=\s*.*|group = "libvirt"|g' /etc/libvirt/qemu.conf
systemctl enable libvirtd.service >/dev/null 2>&1
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

sed -i 's|^\s*#\s*en_US.UTF-8 |en_US.UTF-8 |g' /etc/locale.gen
sed -i 's|^\s*#\s*'"$Locale"' |'"$Locale"' |g' /etc/locale.gen
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

mkdir -p /etc/sudoers.d
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.wheel
EDITOR='cp /etc/sudoers.wheel' visudo -f /etc/sudoers.d/wheel
rm /etc/sudoers.wheel

mkdir -p /etc/dkms/framework.conf.d
echo 'sign_file="/usr/lib/modules/\${kernelver}/build/scripts/sign-file"' > /etc/dkms/framework.conf.d/sign.conf

grub-install --target=x86_64-efi --efi-directory=/efi --removable
mkdir -p /etc/default/grub.d
echo 'GRUB_TIMEOUT=0' > /etc/default/grub.d/grub.cfg
echo 'GRUB_TIMEOUT_STYLE=hidden' >> /etc/default/grub.d/grub.cfg
echo 'GRUB_DEFAULT=saved' >> /etc/default/grub.d/grub.cfg
echo 'GRUB_SAVEDEFAULT=true' >> /etc/default/grub.d/grub.cfg
if [ -n "$KernelCMD" ]
then
  echo 'GRUB_CMDLINE_LINUX_DEFAULT="\$GRUB_CMDLINE_LINUX_DEFAULT ${KernelCMD}"' >> /etc/default/grub.d/grub.cfg
fi
grub-mkconfig -o /boot/grub/grub.cfg
CFG

chmod +x /mnt/Config.sh
arch-chroot /mnt ./Config.sh
rm /mnt/Config.sh

#gdm gnome-shell gnome-control-center gnome-tweaks gnome-terminal nautilus gedit gnome-calculator xdg-desktop-portal-gnome
pacstrap -P /mnt --needed libusb-compat usb_modeswitch smartmontools nvme-cli hdparm zsh grml-zsh-config thermald \
  xorg xf86-input-libinput xf86-input-synaptics xfce4 xfce4-goodies \
  xdg-user-dirs xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-xapp \
  gvfs gvfs-smb gvfs-mtp sshfs catfish which \
  networkmanager network-manager-applet networkmanager-openvpn wireguard-tools wireless-regdb dnsmasq \
  realtime-privileges wireplumber pipewire-alsa pipewire-pulse pipewire-jack pavucontrol openal lib32-openal easyeffects calf \
  bluez bluez-utils blueman \
  cups system-config-printer hplip \
  vulkan-intel lib32-vulkan-intel intel-compute-runtime intel-media-driver intel-gpu-tools \
  nvidia-open-dkms nvidia-utils lib32-nvidia-utils opencl-nvidia lib32-opencl-nvidia nvidia-settings nvidia-prime \
  mesa lib32-mesa mesa-utils vulkan-icd-loader lib32-vulkan-icd-loader vulkan-mesa-layers lib32-vulkan-mesa-layers vulkan-tools \
  ocl-icd lib32-ocl-icd libva lib32-libva libva-utils \
  ttf-roboto ttf-liberation noto-fonts noto-fonts-cjk noto-fonts-emoji terminus-font breeze \
  p7zip zip unzip unrar xarchiver \
  jre-openjdk jdk8-openjdk \
  neofetch htop galculator gparted ntfs-3g mediainfo-gui vlc obs-studio audacity fdkaac gimp steam firefox transmission-gtk mangohud lib32-mangohud flatpak $Packages \
  yad gtk-engines gtk-engine-murrine openssl-1.1
#yes | pacstrap -P /mnt --needed iptables-nft
#compiz-git xfce4-panel-compiz
[ -f chaotic.conf ] && yes '' | pacstrap -C chaotic.conf -i /mnt --needed ttf-ms-fonts qogir-gtk-theme-git qogir-icon-theme-git $Packages2

if [ -n "$WallPaper" ]
then
  if curl -OL "$WallPaper"; then
    mv *.jpg *.png /mnt/usr/share/backgrounds/
  fi
fi

if [ -n "$RGBController" ]
then
  if curl -L "$RGBController" -o RGBController.c; then
    gcc -O2 RGBController.c -o RGBController
    chmod u+s RGBController
    mv RGBController /mnt/usr/local/bin/
cat <<'SVC' > /mnt/etc/systemd/system/RGBController.service
[Unit]
Description=Initialize RGB Controller

[Service]
ExecStart=RGBController

[Install]
WantedBy=multi-user.target
SVC
  fi
fi

cat <<'SHS' > run_jar.sh
#!/bin/bash

if [ "$#" -gt '0' -a -f "$1" ]; then
  app=$(basename "$1")
  app=${app%%.*}
  PREFS="$HOME/.java/.userPrefs/${app,,}/prefs.xml"
  if [ -f "$PREFS" ]; then
    sed -i 's/key\s*=\s*"ftime"\s\s*value\s*=\s*"[^"]*"/key="ftime" value="-2"/gi' "$PREFS"
  fi
  java -jar "$1"
fi
SHS
chmod +x run_jar.sh
mv run_jar.sh /mnt/usr/local/bin/

cat <<'SHS' > genmon-netact.sh
#!/bin/bash
ICON=$(echo -e '\U1F5A7')
SS=$(ss -HQtunp | awk 'NF > 4 && $4 !~ /^127\.0\.0\.1:/ && $4 !~ /^\[::1\]/ {n = split($5, a, "[\"=,()]"); if (n > 7) print a[n-7], a[n-4]}')
INFO=''
LIST=''
if [ -n "$SS" ]; then
	PS=$(echo "$SS" | sort | uniq -c)
	INFO=' '$(echo "$PS" | wc -l)'·'$(echo "$SS" | wc -l)
	LIST=$(echo "$PS" | awk '{printf("%s(%d): %d\n", $2, $3, $1)}')
fi

echo "<txt> <span size='x-large'>${ICON}</span><span rise='2pt'>${INFO}</span> </txt>"
echo "<tool>${LIST}</tool>"
echo "<css>.genmon_value { margin-top: 8px }</css>"
exit 0
SHS
chmod +x genmon-netact.sh
mv genmon-netact.sh /mnt/usr/local/bin/

if curl -OL "${_git%/*}/AudioEnc/raw/main/audio_encode.sh"; then
  chmod +x audio_encode.sh
  mv audio_encode.sh /mnt/usr/local/bin/
fi

cat <<CFG > /mnt/Config.sh
#!/bin/bash

mkdir -p /etc/X11/xorg.conf.d
cat <<'XOR' > /etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
  Identifier "Keyboard Default"
  MatchIsKeyboard "yes"
  Option "XkbLayout" "$KeyLayout"
  Option "XkbVariant" "$KeyVariant"
EndSection
XOR

cat <<'XOR' > /etc/X11/xorg.conf.d/00-mouse.conf
Section "InputClass"
  Identifier "Mouse Default"
  MatchIsPointer "yes"
  Driver "libinput"
  Option "AccelSpeed" "0"
  Option "AccelProfile" "flat"
EndSection
XOR

cat <<'XOR' > /etc/X11/xorg.conf.d/00-nvidia.conf
Section "OutputClass"
  Identifier "nvidia"
  MatchDriver "nvidia-drm"
  Driver "nvidia"
  Option "ConnectToAcpid" "0"
EndSection
XOR

cat <<'XOR' > /etc/X11/xorg.conf.d/05-monitor.conf
Section "Monitor"
  Identifier "eDP-1"
  Modeline "1920x1080_165.00"  525.00  1920 2088 2296 2672  1080 1083 1088 1192 -hsync +vsync
  Modeline "1680x1050_165.00"  446.25  1680 1824 2008 2336  1050 1053 1059 1159 -hsync +vsync
  Modeline "1600x900_165.00"  364.25  1600 1736 1912 2224  900 903 908 994 -hsync +vsync
  Modeline "1280x720_165.00"  230.75  1280 1384 1520 1760  720 723 728 796 -hsync +vsync
XOR
if [ "$Mode" != '0' ]
then
  echo '  Option "PreferredMode" "1920x1080_165.00"' >> /etc/X11/xorg.conf.d/05-monitor.conf
fi
echo 'EndSection' >> /etc/X11/xorg.conf.d/05-monitor.conf

echo '[ -z "\$DISPLAY" ] && [ "\$XDG_VTNR" = 1 ] && exec startxfce4 >/dev/null 2>&1' > /etc/profile.d/zzz-xfce4.sh

mkdir -p /etc/dconf/profile
echo -e "user-db:user\nsystem-db:local" > /etc/dconf/profile/user
mkdir -p /etc/dconf/db/local.d
echo -e "[org/gnome/desktop/interface]\ngtk-theme='Qogir-Dark'\nicon-theme='Qogir-dark'\ncolor-scheme='prefer-dark'\n" > /etc/dconf/db/local.d/gnome
echo -e "[org/gnome/desktop/wm/preferences]\ntheme='Qogir-Dark'\nbutton-layout='appmenu:minimize,maximize,close'\n" >> /etc/dconf/db/local.d/gnome
echo -e "[org/gnome/desktop/peripherals/mouse]\naccel-profile='flat'\n" >> /etc/dconf/db/local.d/gnome
dconf update

sed -i 's|name="ThemeName"[^/]*|name="ThemeName" type="string" value="Qogir-Dark"|g' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
sed -i 's|name="IconThemeName"[^/]*|name="IconThemeName" type="string" value="Qogir-dark"|g' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
cat <<'XFWM' > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Qogir-Dark"/>
  </property>
</channel>
XFWM

#sed -i 's|"xfwm4"|"compiz"|g' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml
#sed -i 's|use_compositing=true|use_compositing=false|g' /usr/share/xfwm4/defaults

sed -i 's|.*</actions>.*||g' /etc/xdg/Thunar/uca.xml
cat <<XDG >> /etc/xdg/Thunar/uca.xml
  <action>
    <icon>application-x-shellscript</icon>
    <name>${LangTexts[0]}</name>
    <command>xfce4-terminal -e &quot;%f&quot;</command>
    <description></description>
    <patterns>*.sh</patterns>
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

  <action>
    <icon>lx-music-desktop</icon>
    <name>Encode</name>
    <command>xfce4-terminal -e &quot;audio_encode.sh %f&quot;</command>
    <description></description>
    <patterns>*</patterns>
    <directories/>
    <audio-files/>
  </action>

XDG
echo '</actions>' >> /etc/xdg/Thunar/uca.xml

sed -i 's|.*\s--ensure-directory\s.*|\tif \[ \$# -gt 1 \]; then\n\t\texec xarchiver --multi-extract "\$@"\n\telse\n\t\texec xarchiver --ensure-directory "\$@"\n\tfi|g' /usr/lib/xfce4/thunar-archive-plugin/xarchiver.tap
sed -i 's|.*\s--extract\s.*|\tif \[ \$# -gt 1 \]; then\n\t\texec xarchiver --multi-extract "\$@"\n\telse\n\t\texec xarchiver --extract "\$@"\n\tfi|g' /usr/lib/xfce4/thunar-archive-plugin/xarchiver.tap

echo '[Removed Associations]' > /etc/xdg/mimeapps.list
awk '\$0 ~ /org\.xfce\.Catfish\.desktop/ {print \$1"=org.xfce.Catfish.desktop"}' FS="=" /usr/share/applications/mimeinfo.cache >> /etc/xdg/mimeapps.list
awk '\$0 ~ /mediainfo-gui\.desktop/ {print \$1"=mediainfo-gui.desktop"}' FS="=" /usr/share/applications/mimeinfo.cache >> /etc/xdg/mimeapps.list

mkdir -p /etc/xdg-desktop-portal
cp /usr/share/xdg-desktop-portal/xfce-portals.conf /etc/xdg-desktop-portal/portals.conf

usermod -a -G realtime $User

mkdir -p /etc/pipewire
cp /usr/share/pipewire/client.conf /etc/pipewire/
cp /usr/share/pipewire/client-rt.conf /etc/pipewire/
cp /usr/share/pipewire/pipewire-pulse.conf /etc/pipewire/
sed -i '/channelmix\.upmix/{s/#//;s/true/false/;s/psd/none/}' /etc/pipewire/client.conf
sed -i '/channelmix\.upmix/{s/#//;s/true/false/;s/psd/none/}' /etc/pipewire/client-rt.conf
sed -i '/channelmix\.upmix/{s/#//;s/true/false/;s/psd/none/}' /etc/pipewire/pipewire-pulse.conf

sed -i '/AutoEnable=/{s/#//;s/true/false/}' /etc/bluetooth/main.conf

sed -i '/"${WiFiDom}"/{s/#//}' /etc/conf.d/wireless-regdom

echo -e '[main]\nsystemd-resolved=false' > /etc/NetworkManager/conf.d/99-systemd-resolved.conf

echo '__GL_FSAA_MODE=0' >> /etc/environment
echo '__GL_FSAAAppControlled=0' >> /etc/environment
echo '__GL_FSAAAppEnhanced=0' >> /etc/environment
echo '__GL_ALLOW_FXAA_USAGE=0' >> /etc/environment
echo '__GL_LOG_MAX_ANISO=0' >> /etc/environment
echo '__GL_SYNC_TO_VBLANK=0' >> /etc/environment
echo '__GL_IGNORE_GLSL_EXT_REQS=1' >> /etc/environment
echo '__GL_THREADED_OPTIMIZATIONS=1' >> /etc/environment
echo '__GL_SHADER_DISK_CACHE=1' >> /etc/environment
echo '__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1' >> /etc/environment
#echo 'LIBGL_DRI3_DISABLE=1' >> /etc/environment
echo 'WINE_DISABLE_WRITE_WATCH=1' >> /etc/environment
echo '#WINE_HIDE_NVIDIA_GPU=1' >> /etc/environment

$XCMD

#irqbalance.service
#nvidia-powerd.service
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1
systemctl enable fstrim.timer thermald.service NetworkManager.service bluetooth.service cups.service >/dev/null 2>&1
#systemctl enable fstrim.timer thermald.service NetworkManager.service bluetooth.service cups.service gdm.service >/dev/null 2>&1

if [ -n "$RGBController" ]
then
  systemctl enable RGBController
fi

mkdir -p /etc/xdg/xfce4/kiosk
echo -e '[xfce4-session]\nSaveSession=NONE\n' > /etc/xdg/xfce4/kiosk/kioskrc

[ -d /etc/ssh/sshd_config.d ] && echo 'PermitRootLogin no' > /etc/ssh/sshd_config.d/99-deny_root.conf

mkdir -p /etc/security/limits.d
echo '* hard nofile 524288' > /etc/security/limits.d/99-file_limit.conf
echo 'vm.max_map_count = 16777216' > /etc/sysctl.d/99-map_count.conf

echo 'dev.i915.perf_stream_paranoid = 0' > /etc/sysctl.d/99-perf_stream.conf
echo 'net.ipv4.icmp_echo_ignore_all = 1' > /etc/sysctl.d/99-ignore_echo.conf
echo 'net.ipv6.icmp.echo_ignore_all = 1' >> /etc/sysctl.d/99-ignore_echo.conf

[ -f /usr/share/glvnd/egl_vendor.d/50_mesa.json ] && mkdir -p /etc/glvnd/egl_vendor.d && cp /usr/share/glvnd/egl_vendor.d/50_mesa.json /etc/glvnd/egl_vendor.d/05_mesa.json

echo -e '[defaults]\nntfs:ntfs3_defaults=uid=\$UID,gid=\$GID,noatime,prealloc' > /etc/udisks2/mount_options.conf

echo 'SUBSYSTEM=="block", ENV{ID_FS_TYPE}=="ntfs", ENV{ID_FS_TYPE}="ntfs3"' > /etc/udev/rules.d/20-ntfs3_by_default.rules

echo 'ACTION=="add|change", KERNEL=="sd[a-z]", ENV{ID_USB_TYPE}=="disk", RUN+="/bin/sh -c '\''echo 1048576 > /sys/block/%k/bdi/max_bytes && echo 1 > /sys/block/%k/bdi/strict_limit'\''"' > /etc/udev/rules.d/99-pendrive.rules

if (( $zramSwapSize > 0 ))
then
  echo 'zram' > /etc/modules-load.d/zram.conf
  echo 'ACTION=="add", KERNEL=="zram0", ATTR{comp_algorithm}="zstd", ATTR{disksize}="'${zramSwapSize}'G", RUN="/usr/bin/mkswap -U clear /dev/%k", TAG+="systemd"' > /etc/udev/rules.d/99-zram.rules
  echo -e "\n# /dev/zram0\n/dev/zram0 none swap defaults,pri=100 0 0" >> /etc/fstab

  echo 'vm.swappiness = 180' > /etc/sysctl.d/99-vm-zram-parameters.conf
  echo 'vm.watermark_boost_factor = 0' >> /etc/sysctl.d/99-vm-zram-parameters.conf
  echo 'vm.watermark_scale_factor = 125' >> /etc/sysctl.d/99-vm-zram-parameters.conf
  echo 'vm.page-cluster = 0' >> /etc/sysctl.d/99-vm-zram-parameters.conf
fi

mkdir -p /etc/systemd/logind.conf.d
echo 'HandleLidSwitch=ignore' > /etc/systemd/logind.conf.d/99-notebook.conf

chsh -s /usr/bin/zsh
chsh -s /usr/bin/zsh "$User"
CFG

chmod +x /mnt/Config.sh
arch-chroot /mnt ./Config.sh
rm /mnt/Config.sh

#chmod 666 Install.log
#cp Install.log "/mnt/home/$User/"

#### #### #### #### #### #### #### ####
swapoff /mnt/swapfile
#swapoff /dev/nvme0n1p2
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

#Compiz:
# Composite
#  Detect Refresh Rate: [ ]
# OpenGL
#  Sync To VBlank: [ ]

#NVidia Passthrough:
# echo 'softdep nvidia pre: vfio-pci' > /etc/modprobe.d/vfio.conf
# echo 'options vfio-pci ids=10de:ffff,10de:ffff' >> /etc/modprobe.d/vfio.conf

#CodeBlocks:
# Linker:
#  Libs: mingwex mingw32 gcc msvcrt kernel32 user32
#  Opts: -nostdlib -Wl,--gc-sections
# Compiler:
#  Opts: -ffunction-sections -fdata-sections
#  Defs: _UCRT
# Toolchain(i686=32,x86_64=64):
#  Res: mingw32-windres
