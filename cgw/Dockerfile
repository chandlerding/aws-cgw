FROM alpine
RUN echo "http://dl-4.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories && apk update && apk add strongswan bird iptables
COPY cgw.sh /usr/local/bin/
ENTRYPOINT [ "/usr/local/bin/cgw.sh" ]
