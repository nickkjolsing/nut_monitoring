FROM alpine:3.20
# util-linux -> nsenter (halt the host); openssh-client -> the ssh shutdown driver
RUN apk add --no-cache nut util-linux openssh-client
COPY entrypoint.sh /entrypoint.sh
# Per-client shutdown drivers + hooks (see shutdown.d/README.md)
COPY shutdown.d/ /etc/nut/shutdown.d/
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]