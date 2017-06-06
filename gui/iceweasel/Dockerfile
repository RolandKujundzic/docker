FROM rk:gui_debian
LABEL maintainer "Roland Kujundzic <roland@kujundzic.de>"

RUN apt-get update && apt-get -y install libcanberra-gtk* iceweasel

USER rk
ENV HOME /home/rk
ENTRYPOINT [ "iceweasel" ]

