FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install essential packages with minimal dependencies
RUN apt update -y && apt install --no-install-recommends -y \
    xfce4-session \
    xfce4-panel \
    xfce4-settings \
    xfce4-terminal \
    tigervnc-standalone-server \
    tigervnc-common \
    tigervnc-tools \
    novnc \
    websockify \
    sudo \
    xterm \
    vim \
    net-tools \
    curl \
    wget \
    git \
    tzdata \
    neofetch \
    btop \
    python3 \
    python3-pip \
    wmctrl \
    mousepad && \
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt update -y && apt install -y --no-install-recommends \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    x11-apps && \
    apt install software-properties-common -y && \
    add-apt-repository ppa:mozillateam/ppa -y && \
    echo 'Package: *' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:jammy";' | tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox && \
    apt update -y && apt install -y --no-install-recommends firefox && \
    apt update -y && apt install -y --no-install-recommends xubuntu-icon-theme && \
    rm -rf /var/lib/apt/lists/*

# Clean up to reduce image size
RUN apt clean && rm -rf /tmp/* /var/tmp/*

RUN mkdir -p /root/.vnc
RUN (echo 'hoang1234' && echo 'hoang1234') | vncpasswd && chmod 600 /root/.vnc/passwd

# Optimized xstartup for lightweight XFCE (disable compositor for smoothness)
RUN echo '#!/bin/sh' > /root/.vnc/xstartup && \
    echo '[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources' >> /root/.vnc/xstartup && \
    echo 'vncconfig -iconic &' >> /root/.vnc/xstartup && \
    echo 'xfconf-query -c xfwm4 -p /general/use_compositing -s false' >> /root/.vnc/xstartup && \
    echo 'xfconf-query -c xsettings -p /Net/ThemeName -s "Greybird"' >> /root/.vnc/xstartup && \
    echo 'xfconf-query -c xsettings -p /Net/IconThemeName -s "Adwaita"' >> /root/.vnc/xstartup && \
    echo 'dbus-launch --exit-with-session startxfce4' >> /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Create note file
RUN cat > /root/note.txt << 'EOF'
Cần Thuê VPS/VNC giá rẻ ib
Discord : duyhoangg.v2
Fb : User.DuyHoangg
EOF

# Create startup script for apps with delays for stability
RUN cat > /root/start_apps.sh << 'EOF'
#!/bin/bash
sleep 5
firefox https://www.facebook.com/User.DuyHoangg &
sleep 3
wmctrl -a "Firefox Web Browser" || wmctrl -a Firefox
sleep 1
mousepad /root/note.txt &
sleep 2
wmctrl -a Mousepad || wmctrl -a "Mousepad Text Editor"
EOF
RUN chmod +x /root/start_apps.sh

# Autostart script
RUN mkdir -p /root/.config/autostart && \
    cat > /root/.config/autostart/start_apps.desktop << 'EOF'
[Desktop Entry]
Type=Application
Exec=/root/start_apps.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Start Apps
Comment=Start Applications
Icon=utilities-terminal
Categories=Utility;
EOF

# Optimized noVNC index
RUN echo '<!DOCTYPE html><html><head><title>noVNC</title><script>window.location.replace("vnc.html?autoconnect=1&resize=scale&fullscreen=1");</script></head><body></body></html>' > /usr/share/novnc/index.html

RUN touch /root/.Xauthority

EXPOSE 5901
EXPOSE 6080

# Optimized VNC command with higher quality but efficient encoding
CMD bash -c "unset SESSION_MANAGER && unset DBUS_SESSION_BUS_ADDRESS && \
    vncserver -localhost no -geometry 1920x1080 -depth 24 -quality 9 -xstartup /root/.vnc/xstartup :1 && \
    openssl req -new -subj \"/C=JP\" -x509 -days 365 -nodes -out self.pem -keyout self.pem && \
    websockify -D --web=/usr/share/novnc/ --cert=self.pem 6080 localhost:5901 && \
    tail -f /dev/null"
