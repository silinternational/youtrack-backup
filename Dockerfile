FROM alpine:3

# Variables set with ARG can be overridden at image build time with
# "--build-arg var=value".  They are not available in the running container.
ARG B2_VERSION=v3.10.0
ARG SENTRY_CLI_VERSION=2.41.1

# Install b2, curl, perl, jq and sentry-cli
RUN cd /tmp \
 && wget -O /usr/local/bin/b2 \
    https://github.com/Backblaze/B2_Command_Line_Tool/releases/download/${B2_VERSION}/b2-linux \
 && chmod +x /usr/local/bin/b2 \
 && apk update \
 && apk add --no-cache curl perl jq \
 && curl -sL https://downloads.sentry-cdn.com/sentry-cli/${SENTRY_CLI_VERSION}/sentry-cli-Linux-x86_64 -o /usr/local/bin/sentry-cli \
 && chmod +x /usr/local/bin/sentry-cli \
 && rm -rf /var/cache/apk/*

COPY ./youtrack-backup.pl  /usr/local/bin/youtrack-backup.pl
COPY ./youtrack-backup.sh  /usr/local/bin/youtrack-backup.sh

WORKDIR /tmp

CMD [ "/usr/local/bin/youtrack-backup.sh" ]
