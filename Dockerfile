FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV USER=root
ENV HOME=/root
WORKDIR /root

RUN apt update && apt install -y \
    xfce4 xfce4-goodies \
    tigervnc-standalone-server \
    novnc websockify \
    firefox \
    dbus-x11 \
    x11-xserver-utils x11-utils \
    xterm \
    sudo curl wget git \
    net-tools \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p ~/.vnc
RUN echo '#!/bin/sh\nunset SESSION_MANAGER\nunset DBUS_SESSION_BUS_ADDRESS\nexec startxfce4 &' > ~/.vnc/xstartup
RUN chmod +x ~/.vnc/xstartup

RUN openssl req -new -x509 -days 365 -nodes \
    -subj "/C=JP" \
    -out /root/self.pem \
    -keyout /root/self.pem

EXPOSE 5901
EXPOSE 6080

CMD bash -c "\
vncserver -localhost no -SecurityTypes None :1 && \
websockify -D --web=/usr/share/novnc/ --cert=/root/self.pem 6080 localhost:5901 && \
tail -f /dev/null"
