FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install base packages
RUN apt update -y && apt install --no-install-recommends -y \
    xfce4 xfce4-goodies tigervnc-standalone-server novnc websockify sudo xterm init systemd snapd vim net-tools curl wget git tzdata \
    dbus-x11 x11-utils x11-xserver-utils x11-apps software-properties-common gnupg ca-certificates \
    && apt clean && rm -rf /var/lib/apt/lists/*

# Install Firefox from Mozilla PPA (manual key addition to avoid gpg-agent issues)
RUN wget -qO - https://ppa.launchpadcontent.net/mozillateam/ppa/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/mozillateam-archive-keyring.gpg && \
    echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/mozillateam-archive-keyring.gpg] https://ppa.launchpadcontent.net/mozillateam/ppa/ubuntu jammy main" | tee /etc/apt/sources.list.d/mozilla-ppa.list > /dev/null && \
    echo 'Package: *' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:jammy";' | tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox && \
    apt update -y && apt install -y firefox && \
    apt clean && rm -rf /var/lib/apt/lists/*

# Install xubuntu-icon-theme
RUN apt update -y && apt install -y xubuntu-icon-theme && \
    apt clean && rm -rf /var/lib/apt/lists/*

# Setup VNC and noVNC
RUN touch /root/.Xauthority && \
    mkdir -p /root/.vnc

# Download and setup ProxVN (Kami Tunnel) client
RUN apt update -y && apt install -y wget tar && \
    wget https://github.com/kami2k1/tunnel/releases/latest/download/kami-tunnel-linux-amd64.tar.gz -O /tmp/tunnel.tar.gz && \
    tar -xzf /tmp/tunnel.tar.gz -C /tmp/ && \
    mv /tmp/kami-tunnel /usr/local/bin/proxvn-tunnel && \
    chmod +x /usr/local/bin/proxvn-tunnel && \
    rm /tmp/tunnel.tar.gz && \
    apt clean && rm -rf /var/lib/apt/lists/*

# Set password (use build arg or env for dynamic, here default to 'password' - override with ARG)
ARG VNC_PASSWORD=password
RUN echo "$VNC_PASSWORD" | vncpasswd -f -stdin > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

EXPOSE 5901 6080

# Start VNC, generate cert, start websockify, and tunnel
CMD bash -c "\
    vncserver -localhost no -SecurityTypes None -geometry 1024x768 --I-KNOW-THIS-IS-INSECURE && \
    openssl req -new -subj '/C=JP' -x509 -days 365 -nodes -out /root/self.pem -keyout /root/self.pem && \
    websockify -D --web=/usr/share/novnc/ --cert=/root/self.pem 0.0.0.0:6080 localhost:5901 & \
    sleep 5 && \
    nohup proxvn-tunnel 6080 > /var/log/tunnel.log 2>&1 & \
    tail -f /dev/null"
