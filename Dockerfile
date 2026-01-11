FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update -y && apt install --no-install-recommends -y \
    xfce4 \
    xfce4-goodies \
    tigervnc-standalone-server \
    tigervnc-common \
    tigervnc-tools \
    novnc \
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

RUN mkdir -p /usr/share/backgrounds
RUN wget -O /usr/share/backgrounds/custom.jpg https://i.pinimg.com/736x/c9/c0/16/c9c0167d5aae25a2e21c6f13ce6b2ca9.jpg

RUN mkdir -p /root/.vnc
RUN (echo 'hoang1234' && echo 'hoang1234') | vncpasswd && chmod 600 /root/.vnc/passwd

# Create xfce4-desktop.xml for custom background
RUN mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml && \
    cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="/usr/share/backgrounds/custom.jpg"/>
          <property name="image-path" type="string" value="/usr/share/backgrounds/custom.jpg"/>
          <property name="image-style" type="int" value="3"/>
          <property name="color-style" type="int" value="0"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF

# Create xstartup for XFCE
RUN echo '#!/bin/sh' > /root/.vnc/xstartup && \
    echo '[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources' >> /root/.vnc/xstartup && \
    echo 'vncconfig -iconic &' >> /root/.vnc/xstartup && \
    echo 'dbus-launch --exit-with-session xfce4-session' >> /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

RUN echo '<!DOCTYPE html><html><head><title>noVNC</title><script>window.location.replace("vnc.html?autoconnect=1&resize=scale&fullscreen=1");</script></head><body></body></html>' > /usr/share/novnc/index.html

RUN touch /root/.Xauthority

EXPOSE 5901
EXPOSE 6080

CMD bash -c "unset SESSION_MANAGER && unset DBUS_SESSION_BUS_ADDRESS && \
    vncserver -localhost no -geometry 1920x1080 -xstartup /root/.vnc/xstartup :1 && \
    openssl req -new -subj \"/C=JP\" -x509 -days 365 -nodes -out self.pem -keyout self.pem && \
    websockify -D --web=/usr/share/novnc/ --cert=self.pem 6080 localhost:5901 && \
    tail -f /dev/null"
