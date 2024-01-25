### BUILD STEP ###

FROM ruby:3.0.3-alpine AS builder

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

FROM ruby:3.0.3-alpine

ARG SINATRA_ROOT=/usr/src/app/

RUN apk update && apk upgrade && apk add --update --no-cache \
  bash \
  tzdata \
  python3 \
  git \
  ffmpeg \
  vim && rm -rf /var/cache/apk/* && ln -sf python3 /usr/bin/python

WORKDIR $SINATRA_ROOT

COPY --from=builder $SINATRA_ROOT $SINATRA_ROOT
COPY --from=builder /usr/local/bundle/ /usr/local/bundle/

RUN python3 -m ensurepip
RUN pip3 install --upgrade pip setuptools
RUN pip3 install git+https://github.com/ytdl-org/youtube-dl.git@master#egg=youtube_dl

CMD ["ruby", "./app.rb"]
