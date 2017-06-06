FROM rk:gui_ubuntu
LABEL maintainer "Roland Kujundzic <roland@kujundzic.de>"

# install latest chrome
# RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
# RUN echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list

RUN apt-get update && apt-get install -y libcanberra-gtk* chromium-browser

USER rk
ENV HOME /home/rk
ENTRYPOINT [ "chromium-browser" ]
