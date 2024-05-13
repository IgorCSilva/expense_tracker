## Creating project

- Create project with bundle:
`bundle gem expense_tracker`

- Add Dockerfile:

- Dockerfile
```dockerfile
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
```

Add docker-compose.

- docker-compose.yaml
```yaml
version: '3'

services:
  spec_test:
    build:
      context: .
    container_name: rspec_test
    volumes:
      - .:/app

```

Now execute the application.
`docker-compose up --build`

Add dependencies.
```ruby
  # Uncomment to register a new dependency of your gem
  spec.add_dependency "rspec", "~> 3.6.0"
  spec.add_dependency "coderay", "~> 1.1.1"
  spec.add_dependency "rack-test", "~> 0.7.0"
  spec.add_dependency "sinatra", "~> 2.0.0"
  spec.add_dependency "base64", "~> 0.1.0"
  spec.add_dependency "webrick", "~> 1.8.1"
```

In container, install the dependencies.
`docker exec -it expense_tracker bash`
`bundle install`

Now, set up the project to use RSpec.

`bundle exec rspec --init`

Running `rspec` with `bundle exec` we make sure we're using the exact library version we're expect.

This command will generate two files:
- .rspec: which contains default command-line flags;
- spec/spec_helper.rb: which contains configuration options.

The default flags in .rspec will cause RSpec to load spec_helper.rb for us before loading and running our spec files.

We need to add a line at the top of spec_helper file.
- spec/spec_helper.rb
```ruby
ENV['RACK_ENV'] = 'test'
```

## Deciding What to Test First

Create the test file.

- spec/acceptance/expense_tracker_api_spec.rb
```ruby

require 'rack/test'
require 'json'

module ExpenseTracker
  RSpec.describe 'Expense Tracker API' do
    include Rack::Test::Methods

    it 'records submitted expenses' do
      coffee = {
        'payee' => 'Starbucks',
        'amount' => 5.75,
        'date' => '2017-06-10'
      }

      post '/expenses', JSON.generate(coffee)
    end
  end
end
```

We're using regular Ruby floating-point numbers to represent expense amount, but in a real project we'd either use the BigDecimal class built into Ruby or a dedicated currency library like the Money gem.

Now, running the test we get the error below.
`bundle exec rspec`

```
F

Failures:

  1) Expense Tracker API records submitted expenses
     Failure/Error: post '/expenses', JSON.generate(coffee)
     
     NameError:
       undefined local variable or method `app' for #<RSpec::ExampleGroups::ExpenseTrackerAPI:0x00007f5d24c56ee8>

  <<truncated>>
```

We need implement the app method.

Just above the `it` line, put:
```ruby
def app()
  ExpenseTracker::API.new()
end
```

Run the tests again.
`bundle exec rspec`

```
F

Failures:

  1) Expense Tracker API records submitted expenses
     Failure/Error: ExpenseTracker::API.new()
     
     NameError:
       uninitialized constant ExpenseTracker::API
```

Create the app file.

- app/api.rb
```rb

require 'sinatra/base'
require 'json'

module ExpenseTracker
  class API < Sinatra::Base
  end
end
```

and load it in a test file:
```rb
require_relative '../../app/api'
```

Now, the spec will pass.

## Checking the Response

Right after the post method, add the line below.
```rb
      expect(last_response.status).to eq(200)
```

Run specs.
You will receive the 404 error.

Then, add the post method inside the API class.
- app/api.rb
```rb
    post '/expenses' do
    end
```

The specs will pass.

## Filling In the Response Body

Add theses two lines at the bottom of `it` block.
```rb
      parsed = JSON.parse(last_response.body)
      expect(parsed).to include('expense_id' => a_kind_of(Integer))
```

Run the tests. You will receive the failed message.

Add the code in API post response.
```rb
JSON.generate('expense_id' => 42)
```

The tests will pass.

## Querying the Data

Change test file to extract the post expense action.
```rb
def post_expense(expense)
      post '/expenses', JSON.generate(expense)
      expect(last_response.status).to eq(200)

      parsed = JSON.parse(last_response.body)
      expect(parsed).to include('expense_id' => a_kind_of(Integer))

      expense.merge('id' => parsed['expense_id'])
    end

    it 'records submitted expenses' do
      coffee = post_expense({
        'payee' => 'Starbucks',
        'amount' => 5.75,
        'date' => '2017-06-10'
      })

      zoo = post_expense({
        'payee' => 'Zoo',
        'amount' => 15.25,
        'date' => '2017-06-10'
      })

      groceries = post_expense({
        'payee' => 'Whole Foods',
        'amount' => 95.20,
        'date' => '2017-06-11'
      })
 
    end
```

And now, get all the expenses for June 10th adding the code below at the bottom of `it` block.

```rb
      get '/expenses/2017-06-10'
      expect(last_response.status).to eq(200)

      expenses = JSON.parse(last_response.body)
      expect(expenses).to contain_exactly(coffee, zoo)
```

If we care about the order, we use `eq [coffee, zoo]`.

Finally, implement the get method in the api file.
```rb
    get '/expenses/:date' do
      JSON.generate([])
    end
```

You will see the incorrect response message now.

## Saving Your Progress: Pending Specs

Add this at the top in `it` block.
```rb
      pending 'Need to persist expenses'
```

Now, you will receive only warnings.

Rack, the HTTP toolkit that Sinatra is built on top of, ships with a tool named rackup that makes it easy to run any Rack application. We just need to define a rackup config file named config.ru with the following contents:

- config.ru
```ru
require_relative 'app/api'
run ExpenseTracker::API.new
```

We're just loading our application and telling Rack to run it.

Then, run the rackup to boot our application.
`bundle exec rackup -o 0.0.0.0`

The -o option tells Rack to bind to all available network interfaces.

Now, running the curl command you will receive the response:
`curl localhost:9292/expenses/2017-06-10 -w "\n"`

Response: []