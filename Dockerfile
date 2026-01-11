FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update -y && apt install --no-install-recommends -y \
    xfce4 \
    xfce4-goodies \
    tigervnc-standalone-server \
    tigervnc-common \
    tigervnc-tools \
    websockify \
    sudo \
    xterm \
    init \
    systemd \
    snapd \
    vim \
    net-tools \
    curl \
    wget \
    git \
    tzdata

RUN apt update -y && apt install -y \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    x11-apps

RUN apt install software-properties-common -y

RUN add-apt-repository ppa:mozillateam/ppa -y

RUN echo 'Package: *' >> /etc/apt/preferences.d/mozilla-firefox
RUN echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox
RUN echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox

RUN echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:jammy";' | tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox

RUN apt update -y && apt install -y firefox

RUN apt update -y && apt install -y xubuntu-icon-theme

# Install latest noVNC from GitHub
RUN git clone https://github.com/novnc/noVNC.git /usr/share/novnc

RUN mkdir -p /root/Pictures
RUN wget -O /root/Pictures/background.jpg https://i.pinimg.com/736x/c9/c0/16/c9c0167d5aae25a2e21c6f13ce6b2ca9.jpg

RUN mkdir -p /root/.vnc
RUN (echo 'hoang1234' && echo 'hoang1234') | vncpasswd && chmod 600 /root/.vnc/passwd

RUN cat > /root/.vnc/xstartup << 'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
xsetroot -solid grey
vncconfig -iconic &
startxfce4 &
sleep 3 && xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s /root/Pictures/background.jpg
EOF
RUN chmod +x /root/.vnc/xstartup

RUN echo '<!DOCTYPE html><html><head><title>noVNC</title><script>window.location.replace("vnc.html?autoconnect=true&password=hoang1234&resize=scale&fullscreen=1");</script></head><body></body></html>' > /usr/share/novnc/index.html

RUN touch /root/.Xauthority

EXPOSE 5901
EXPOSE 6080

CMD bash -c "vncserver -localhost no -geometry 1920x1080 && \
    websockify -D --web=/usr/share/novnc/ 6080 localhost:5901 && \
    tail -f /dev/null"
