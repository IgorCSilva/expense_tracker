# Use the official Ruby image from Docker Hub
FROM ruby:3.3.1

# Set the working directory inside the container
WORKDIR /app

# Copy the Gemfile and Gemfile.lock into the container
# COPY Gemfile* *.gemspec lib ./
COPY . .

# Install dependencies using Bundler
RUN bundle install

# Copy the rest of the application code into the container
# COPY . .

# Keeps the container available.
CMD ["tail", "-f", "/dev/null"]