FROM alpine:3.6
MAINTAINER Benjamin Böhmke <benjamin@boehmke.net>

RUN apk add --no-cache mysql-client postgresql-client postgresql-bdr

ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["app:init"]
