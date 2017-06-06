FROM alpine:latest
LABEL maintainer "Roland Kujundzic <roland@kujundzic.de>"

RUN apk add --no-cache certbot

#
# docker volume 
# docker run -it rk:letsencrypt -v docroot:/docroot --rm domain.tld 
#

CMD certbot --webroot --webroot-path /docroot --agree-tos --renew-by-default -m letsencrypt@inkoeln.com -d $1 certonly

