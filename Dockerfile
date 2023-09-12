FROM alpine:3

# Install b2, curl, perl, jq
RUN cd /tmp \
 && wget -O /usr/local/bin/b2 \
    https://github.com/Backblaze/B2_Command_Line_Tool/releases/latest/download/b2-linux \
 && chmod +x /usr/local/bin/b2 \
 && apk update \
 && apk add --no-cache curl perl jq \
 && rm -rf /var/cache/apk/*

COPY ./youtrack-backup.pl  /usr/local/bin/youtrack-backup.pl
COPY ./youtrack-backup.sh  /usr/local/bin/youtrack-backup.sh

WORKDIR /tmp

CMD [ "/usr/local/bin/youtrack-backup.sh" ]
