FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install base packages
RUN apt update -y && apt install --no-install-recommends -y \
    xfce4 xfce4-goodies tigervnc-standalone-server tigervnc-common novnc websockify sudo xterm init systemd snapd vim net-tools curl wget git tzdata \
    dbus-x11 x11-utils x11-xserver-utils x11-apps software-properties-common gnupg ca-certificates \
    && apt clean && rm -rf /var/lib/apt/lists/*

# Install Firefox from Official Mozilla Repository
RUN install -d -m 0755 /etc/apt/keyrings && \
    wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null && \
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | tee /etc/apt/sources.list.d/mozilla.list > /dev/null && \
    echo 'Package: *' | tee /etc/apt/preferences.d/mozilla && \
    echo 'Pin: origin packages.mozilla.org' >> /etc/apt/preferences.d/mozilla && \
    echo 'Pin-Priority: 1000' >> /etc/apt/preferences.d/mozilla && \
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
RUN echo "$VNC_PASSWORD" | tigervncpasswd -f > /root/.vnc/passwd && \
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
