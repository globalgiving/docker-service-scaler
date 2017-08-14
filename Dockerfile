FROM alpine:3.6
RUN apk add --update bash ca-certificates jq groff python py-pip py-setuptools curl \
     && pip install awscli \
     && pip install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz \
     && apk --purge -v del py-pip \
     && rm -rf /var/cache/apk/*
RUN mkdir -p /usr/docker /var/log/docker/
ADD crontab.txt /usr/docker/crontab.txt
ADD scaler.sh /usr/bin/
COPY entry.sh /entry.sh
RUN chmod 755 /entry.sh /usr/bin/scaler.sh
RUN /usr/bin/crontab /usr/docker/crontab.txt
CMD ["/entry.sh"]
