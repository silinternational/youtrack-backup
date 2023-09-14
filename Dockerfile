FROM alpine:3

# Variables set with ARG can be overridden at image build time with
# "--build-arg var=value".  They are not available in the running container.
ARG B2_VERSION=v3.10.0

# Install b2, curl, perl, jq
RUN cd /tmp \
 && wget -O /usr/local/bin/b2 \
    https://github.com/Backblaze/B2_Command_Line_Tool/releases/download/${B2_VERSION}/b2-linux \
 && chmod +x /usr/local/bin/b2 \
 && apk update \
 && apk add --no-cache curl perl jq \
 && rm -rf /var/cache/apk/*

COPY ./youtrack-backup.pl  /usr/local/bin/youtrack-backup.pl
COPY ./youtrack-backup.sh  /usr/local/bin/youtrack-backup.sh

WORKDIR /tmp

CMD [ "/usr/local/bin/youtrack-backup.sh" ]
