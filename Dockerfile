### BUILD STEP ###

FROM ruby:3.0-alpine AS builder

RUN apk update && apk upgrade && apk add --update --no-cache \
  build-base \
  curl-dev \
  tzdata \
  vim && rm -rf /var/cache/apk/*

ARG SINATRA_ROOT=/usr/src/app/
WORKDIR $SINATRA_ROOT

COPY Gemfile* $SINATRA_ROOT
RUN bundle install

COPY . .

### BUILD STEP DONE ###

FROM ruby:3.0-alpine

ARG SINATRA_ROOT=/usr/src/app/

RUN apk update && apk upgrade && apk add --update --no-cache \
  bash \
  tzdata \
  vim && rm -rf /var/cache/apk/*

WORKDIR $SINATRA_ROOT

COPY --from=builder $SINATRA_ROOT $SINATRA_ROOT
COPY --from=builder /usr/local/bundle/ /usr/local/bundle/

EXPOSE 9292

CMD ["rackup", "config.ru", "-o", "0.0.0.0"]
