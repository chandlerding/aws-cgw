FROM alpine
RUN echo "http://dl-4.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories && apk update && apk add bird && mkdir /etc/bird.d
COPY bird.conf /etc/bird.conf
COPY bird.sh /usr/local/bin/
ENTRYPOINT ["/usr/sbin/bird" , "-f"]
