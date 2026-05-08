### BUILD STEP ###

FROM ruby:3.4.7-alpine AS builder

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

FROM ruby:3.4.7-alpine

ARG SINATRA_ROOT=/usr/src/app/

RUN apk update && apk upgrade && apk add --update --no-cache \
  bash \
  curl \
  tzdata \
  python3 \
  nodejs \
  git \
  ffmpeg \
  vim && rm -rf /var/cache/apk/* && ln -sf python3 /usr/bin/python

WORKDIR $SINATRA_ROOT

COPY --from=builder $SINATRA_ROOT $SINATRA_ROOT
COPY --from=builder /usr/local/bundle/ /usr/local/bundle/

RUN curl -fsSL -o /usr/local/bin/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
  && chmod +x /usr/local/bin/yt-dlp \
  && yt-dlp --version

CMD ["ruby", "./app.rb"]
