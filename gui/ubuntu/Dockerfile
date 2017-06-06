FROM ubuntu:17.04
LABEL maintainer "Roland Kujundzic <roland@kujundzic.de>"

ENV TERM xterm-256color

# be noninteractive only during build
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
	apt-get install -y --no-install-recommends dialog apt-utils sudo wget && \
	rm -rf /var/lib/apt/lists/*

# Replace uid.gid = 1000.1000 if necessary
RUN export uid=1000 gid=1000 && \
  mkdir -p /home/rk && \
  echo "rk:x:${uid}:${gid}:rk,,,:/home/rk:/bin/bash" >> /etc/passwd && \
  echo "rk:x:${uid}:" >> /etc/group && \
  echo "rk ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/rk && \
  chmod 0440 /etc/sudoers.d/rk && \
  chown ${uid}:${gid} -R /home/rk && \
	usermod -a -G audio,video rk

ENV DISPLAY :0

ENTRYPOINT [ "/bin/bash" ]

