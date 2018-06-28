FROM ruby:2.5-slim-stretch
RUN apt-get update -y && \
    apt-get install --no-install-recommends -y \
    automake=1:1.15-6 \
    build-essential=12.3 \
    ssh=1:7.4p1-10+deb9u3 \
    git=1:2.11.0-3+deb9u2 \
    curl=7.52.1-5+deb9u6 \
 && rm -rf /var/lib/apt/lists/*
ARG SSH_KEY
ARG BUNDLE_WITHOUT
ENV BUNDLE_WITHOUT="$BUNDLE_WITHOUT"
RUN mkdir /root/.ssh
RUN echo "$SSH_KEY" > /root/.ssh/id_rsa
RUN chmod 400 /root/.ssh/id_rsa
RUN ssh-keyscan github.com > /root/.ssh/known_hosts
RUN ssh-keyscan bitbucket.org >> /root/.ssh/known_hosts
WORKDIR /home/app
EXPOSE 3000
COPY Gemfile* ./
RUN bundle install --jobs 20 --retry 5
COPY . .
CMD ["bundle", "exec", "rails", "s"]
