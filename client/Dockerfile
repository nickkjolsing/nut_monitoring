FROM alpine:3.20
RUN apk add --no-cache nut util-linux   # util-linux -> nsenter, to halt the host
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]