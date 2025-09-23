# Use an official Erlang image as the base
FROM elixir:1.18.4-otp-27


# Install dependencies and inotify-tools
RUN apt-get update && apt-get install -y curl git bash inotify-tools build-essential nodejs npm 


# Set up project folder
ENV APP_HOME=/app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

RUN mix local.hex --force && \
    mix local.rebar --force