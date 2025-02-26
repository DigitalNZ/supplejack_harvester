FROM ruby:3.2.5-alpine3.20

WORKDIR /app

ARG BUILD_PACKAGES="build-base curl-dev git"
# AWS CLI is used to run the S3 extraction
ARG DEV_PACKAGES="bash mysql-client mariadb-dev yaml-dev zlib-dev nodejs yarn libxml2 libxml2-dev libxslt libxslt-dev gmp-dev openjdk8-jre python3 py3-pip aws-cli chromium chromium-chromedriver"
ARG RUBY_PACKAGES="tzdata"

WORKDIR /app

# Install packages
RUN apk add --update --no-cache $BUILD_PACKAGES $DEV_PACKAGES $RUBY_PACKAGES

RUN apk add tesseract-ocr tesseract-ocr-data-eng ocrmypdf --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community

COPY Gemfile Gemfile.lock ./

RUN gem install bundler -v $(tail -n1 Gemfile.lock) \
    && bundle config set --local frozen 1 \
    && bundle config set --local without development:test \
    && bundle config set --local path vendor/cache \
    && bundle config set --local build.nokogiri --use-system-libraries \
    && bundle install --jobs=4 --retry=3 \
    # Remove unneeded files (cached *.gem, *.o, *.c)
    && rm -rf $GEM_HOME/cache/*.gem \
    && find $GEM_HOME/gems/ -name "*.c" -delete \
    && find $GEM_HOME/gems/ -name "*.o" -delete

COPY package.json yarn.lock ./
RUN yarn install --production

COPY . .

ARG RAILS_ENV="production"
ENV RAILS_ENV=$RAILS_ENV
ARG RAILS_MASTER_KEY
ENV RAILS_MASTER_KEY=$RAILS_MASTER_KEY
ARG RAILS_SECRET_KEY_BASE
ENV SECRET_KEY_BASE=$RAILS_SECRET_KEY_BASE

RUN bundle exec rails assets:precompile

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
