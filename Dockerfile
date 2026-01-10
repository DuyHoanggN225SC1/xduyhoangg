#!/bin/bash
# Copyright(C) 2025 Mrbeenopro https://mrbeeno.pro All rights reserved.
# Merged setup: Alpine proot with QEMU Ubuntu VM configured via cloud-init for XFCE noVNC desktop, integrated with ProxVN (Kami Tunnel) for public exposure.
# System Configuration
user_passwd="$(echo "$HOSTNAME" | sed 's+-.*++g')"
debug=false
meow="meows"
mirror_alpine="https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-minirootfs-3.22.2-x86_64.tar.gz"
mirror_proot="https://proot.gitlab.io/proot/bin/proot"
if "$debug"; then
  install_path=$HOME/alpine_subsystem
elif [ -n "$SERVER_PORT" ]; then
  install_path="$HOME/.cache/JNA/temp/temp-$P_SERVER_UUID"
  mkdir -p "$install_path"
  date > "$install_path/.created_at"
else
  install_path="./testing-arena"
fi
d.stat() { echo -ne "\033[1;37m==> \033[1;34m$@\033[0m\n"; }
die() {
  echo -ne "\n\033[41m \033[1;37mA FATAL ERROR HAS OCCURED \033[0m\n"
  exit 1
}
# <dbgsym:bootstrap>
check_link="curl --output /dev/null --silent --head --fail"
bootstrap_system() {
  _CHECKPOINT=$PWD
  d.stat "Initializing the Alpine rootfs image..."
  curl -L "$mirror_alpine" -o a.tar.gz && tar -xf a.tar.gz || die
  rm -rf a.tar.gz
  d.stat "Downloading a Docker Daemon..."
  curl -L "$mirror_proot" -o paper || die
  chmod +x paper
  d.stat "Bootstrapping system..."
  touch etc/{passwd,shadow,groups}
  cp /etc/resolv.conf "$install_path/etc/resolv.conf" -v
  cp /etc/hosts "$install_path/etc/hosts" -v
  cp /etc/localtime "$install_path/etc/localtime" -v
  cp /etc/passwd "$install_path"/etc/passwd -v
  cp /etc/group "$install_path"/etc/group -v
  cp /etc/nsswitch.conf "$install_path"/etc/nsswitch.conf -v
  mkdir -p "$install_path/home/container"
 
  d.stat "Downloading will took 5-15 minutes.."
  ./paper -r . -b /dev -b /sys -b /proc -b /tmp \
    --kill-on-exit -w /home/container /bin/sh -c " \
        apk update && apk add bash xorg-server unzip python3 virtiofsd py3-pip py3-numpy \
            xinit xvfb fakeroot qemu qemu-img qemu-system-x86_64 \
            virtualgl mesa-dri-gallium cdrtools \
            --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing \
            --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community \
            --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main && \
        wget -O disk.img https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img && \
        wget -O OVMF.fd https://pub-cc2caec4959546c9b98850c80420b764.r2.dev/OVMF.fd && \
        cat > user-data << 'EOF'
#cloud-config
package_update: true
package_upgrade: true
packages:
  - xfce4
  - xfce4-goodies
  - tigervnc-standalone-server
  - novnc
  - websockify
  - sudo
  - xterm
  - vim
  - net-tools
  - curl
  - wget
  - git
  - tzdata
  - dbus-x11
  - x11-utils
  - x11-xserver-utils
  - x11-apps
  - software-properties-common
  - xubuntu-icon-theme
runcmd:
  - export DEBIAN_FRONTEND=noninteractive
  - add-apt-repository ppa:mozillateam/ppa -y
  - bash -c 'echo "Package: * " > /etc/apt/preferences.d/mozilla-firefox && echo "Pin: release o=LP-PPA-mozillateam" >> /etc/apt/preferences.d/mozilla-firefox && echo "Pin-Priority: 1001" >> /etc/apt/preferences.d/mozilla-firefox'
  - bash -c 'echo '"'"'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:jammy";'"'"' | tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox'
  - apt-get update -y
  - apt-get install -y firefox
  - user_passwd=$(echo "$HOSTNAME" | sed 's+-.*++g')
  - mkdir -p /root/.vnc
  - echo $user_passwd | vncpasswd -f -stdin > /root/.vnc/passwd
  - chmod 600 /root/.vnc/passwd
  - touch /root/.Xauthority
  - vncserver -localhost no -SecurityTypes None -geometry 1024x768 --I-KNOW-THIS-IS-INSECURE
  - openssl req -new -subj \"/C=JP\" -x509 -days 365 -nodes -out /root/self.pem -keyout /root/self.pem
  - nohup websockify -D --web=/usr/share/novnc/ --cert=/root/self.pem 0.0.0.0:6080 localhost:5901 &
EOF
        && \
        cat > meta-data << 'METADATA'
instance-id: ubuntu-desktop-vm
local-hostname: desktop-vm
METADATA
        && \
        mkisofs -output cidata.iso -volid cidata -joliet -rock user-data meta-data && \
        rm user-data meta-data
    " || die
}
# </dbgsym:bootstrap>
DOCKER_RUN="env - \
    HOME=$install_path/home/container $install_path/paper --kill-on-exit -r $install_path -b /dev -b /proc -b /sys -b /tmp \
    -b $install_path:$install_path /bin/sh -c"
run_system() {
  if [ -f $HOME/.do-not-start ]; then
    rm -rf $HOME/.do-not-start
    cp /etc/resolv.conf "$install_path/etc/resolv.conf" -v
    $DOCKER_RUN /bin/sh
    exit
  fi
  d.stat "Starting System..."
  $install_path/paper --kill-on-exit -r $install_path -b /dev -b /proc -b /sys -b /tmp -w "/home/container/" /bin/sh -c "qemu-system-x86_64 -m $((SERVER_MEMORY - 2048)) -overcommit mem-lock=off -cpu EPYC-Milan,+sse,+sse2,+sse4.1,+sse4.2,hv-relaxed -smp sockets=1,cores=2,threads=1 -pflash OVMF.fd -nic user,hostfwd=tcp::2200-:22,hostfwd=tcp::8080-:80,hostfwd=tcp::2022-:2202,hostfwd=tcp::443-:4430,hostfwd=tcp::$SERVER_PORT-:6080 -drive file=disk.img,format=raw,aio=native,cache.direct=on,if=virtio -cdrom cidata.iso -accel tcg,thread=multi,tb-size=128,split-wx=on -usbdevice tablet -monitor stdio" &>/dev/null &
  sleep 60  # Wait for VM to boot and cloud-init to install/setup
  d.stat "Downloading ProxVN Tunnel..."
  curl -L https://github.com/kami2k1/tunnel/releases/latest/download/proxvn-linux-client -o /tmp/proxvn-linux-client || die
  chmod +x /tmp/proxvn-linux-client
  d.stat "Starting tunnel for port $SERVER_PORT..."
  nohup /tmp/proxvn-linux-client $SERVER_PORT > /tmp/tunnel.log 2>&1 &
  echo -ne "[$(date +%H:%M) INFO]: Done (36.67s)! For help, type help"
  d.stat "Your local noVNC is now available at \033[1;32mhttp://localhost:$SERVER_PORT/vnc.html\033[0m (password: $user_passwd)"
  d.stat "Check \033[1;32m/tmp/tunnel.log\033[0m for the public tunnel URL"                     
  $DOCKER_RUN bash
}
cd "$install_path" || {
  mkdir -p "$install_path"
  cd "$install_path"
}
[ -d "bin" ] && run_system || bootstrap_system
