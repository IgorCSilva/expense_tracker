## From Acceptance Specs to Unit Specs

Add this line inside the RSpec.configure.

- spec/spec_helper.rb
```rb
  config.filter_gems_from_backtrace 'rack', 'rack-test', 'sequel', 'sinatra'
```

When an error happens in a Ruby application, the stack trace often includes not only the lines of code from your application but also lines from the gems (libraries) your application depends on. Filtering out the gem lines can make the stack trace cleaner and more focused on your application's code, which can make debugging easier.

But, if you need to see the full backtrace, uou still can do this passing the --backtrace or -b flag to RSpec.

### Sketching the Behavior

Create the file:

- spec/unit/app/api_spec.rb
```rb

require_relative '../../../app/api'

module ExpenseTracker
  RSpec.describe API do
    describe 'POST /expenses' do
      context 'when the expense is successfully recorded' do
        it 'returns the expense id'
        it 'responds with a 200 (OK)'
      end

      context 'when the expense fails validation' do
        it 'returns an error message'
        it 'responds with a 422 (Unprocessable entity)'
      end
    end
  end
end
```

Run the tests.
`bundle exec rspec spec/unit/app/api_spec.rb`

You will see 4 warnings. Ok for now.

## Filling In the First Spec

### Connecting to Storage

Let's create an storage engine that keeps the expene history.

Create the file:

- api_snippets.rb
```rb

class API < Sinatra::Base
  def initialize(ledger:)
    @ledger = ledger
    super() # rest of initialization from Sinatra.
  end
end

# Later, callers do this:
app = API.new(ledger: Ledger.new)

# Pseudocode for what happens inside the API class:

# result = @ledger.record({ 'some' => 'data' })
# result.success? # => a Boolean
# result.expense_id # => a number
# result.error_message # => a string or nil
```

And update the api.rb file.

```rb
...
  class API < Sinatra::Base

    def initialize(ledger)
      @ledger = ledger
      super()
    end

    post '/expenses' do
...
```

When the HTTP POST request arrives, the API class will tell the Ledger to record() the expense.

### Test Doubles: Mocks, Stubs, and Others

Add some configuration.

- spec/unit/app/api_spec.rb
```rb
require_relative '../../../app/api'
require 'rack/test'

module ExpenseTracker

  RecordResult = Struct.new(:success?, :expense_id, :error_message)

  RSpec.describe API do
    include Rack::Test::Methods

    def app()
      API.new(ledger)
    end

    let(:ledger) { instance_double('ExpenseTracker::Ledger') }
    
    ...
```

Now, update the `it` block:
```ruby
  it 'returns the expense id' do
    expense = { 'some' => 'data' }

    allow(ledger).to receive(:record)
      .with(expense)
      .and_return(RecordResult.new(true, 417, nil))

    post '/expenses', JSON.generate(expense)

    parsed = JSON.parse(last_response.body)
    expect(parsed).to include('expense_id' => 417)
  end
```

We’re calling the allow method from rspec-mocks.
This method configures the test double’s behavior: when the caller (the API class) invokes record, the double will return a new RecordResult instance indicating a successful posting.

## Handling Success

Change the /expenses route in api.rb:
```rb
    post '/expenses' do
      expense = JSON.parse(request.body.read)
      result = @ledger.record(expense)

      JSON.generate('expense_id' => result.expense_id)
    end
```

Run the tests and one must be pass.

Fill another test:
```rb
        it 'responds with a 200 (OK)' do
          expense = { 'some' => 'data' }

          allow(ledger).to receive(:record)
            .with(expense)
            .and_return(RecordResult.new(true, 417, nil))

          post '/expenses', JSON.generate(expense)
          expect(last_response.status).to eq(200)
        end
```

This test should pass.

Let's break the response to see what happens.

```rb
    post '/expenses' do
      status 404

      ...
```

Now we have an error.
Fix this bug before proceed.

## Refactoring

Put the code below inside the first context block:

- spec/unit/app/api_spec.rb
```rb
  let(:expense) { { 'some' => 'data' } }

  before do
    allow(ledger).to receive(:record)
      .with(expense)
      .and_return(RecordResult.new(true, 417, nil))
  end
```

and remove the setup code from tests:
```rb
  it 'returns the expense id' do

    post '/expenses', JSON.generate(expense)

    parsed = JSON.parse(last_response.body)
    expect(parsed).to include('expense_id' => 417)
  end

  it 'responds with a 200 (OK)' do

    post '/expenses', JSON.generate(expense)
    expect(last_response.status).to eq(200)
  end
```

The tests should keep pass.

## Handling Failure

Update the code inside the failed context block.
```rb
  context 'when the expense fails validation' do
    let(:expense) { { 'some' => 'data' } }

    before do
      allow(ledger).to receive(:record)
        .with(expense)
        .and_return(RecordResult.new(false, 417, 'Expense incomplete'))
    end

    it 'returns an error message' do
      post '/expenses', JSON.generate(expense)

      parsed = JSON.parse(last_response.body)
      expect(parsed).to include('error' => 'Expense incomplete')
    end

    it 'responds with a 422 (Unprocessable entity)' do
      post '/expenses', JSON.generate(expense)
      expect(last_response.status).to eq(422)
    end
  end
```

Then update the api post method:
```rb
    post '/expenses' do
      expense = JSON.parse(request.body.read)
      result = @ledger.record(expense)

      if result.success?
        JSON.generate('expense_id' => result.expense_id)
      else
        status 422
        JSON.generate('error' => result.error_message)
      end
    end
```

All tests should pass.

## Defining the Ledger

Create a file:

- app/ledger.rb
```rb

module ExpenseTracker
  RecordResult = Struct.new(:success?, :expense_id, :error_message)

  class Ledger
    def record(expense)
      
    end
  end
end
```

Remove the RecordResult declaration from `spec/unit/app/api_spec.rb`.

Import in api file:
- app/api.rb
```rb
require_relative 'ledger'
```

The test should pass.

Implement the GET method tests:

```rb
    describe 'GET /expenses/:date' do
      context 'when expenses exist on the given date' do

        let(:expense) { { 'some' => 'data' } }
        let(:date) { '2017-06-01' }

        before do
          allow(ledger).to receive(:expenses_on)
            .with(date)
            .and_return(ExpensesResult.new(true, [expense], nil))
        end

        it 'returns the expense records as JSON' do
          get '/expenses/2017-06-01'

          check_response(
            last_response,
            include('expenses' => [expense])
          )
        end
        
        it 'responds with a 200 (OK)' do
          get '/expenses/2017-06-01'
          expect(last_response.status).to eq(200)
        end
      end

      context 'when there are no expenses on the given date' do

        let(:date) { '2017-06-01' }

        before do
          allow(ledger).to receive(:expenses_on)
            .with(date)
            .and_return(ExpensesResult.new(true, [], nil))
        end

        it 'returns an empty array as JSON' do
          get '/expenses/2017-06-01'

          check_response(
            last_response,
            include('expenses' => [])
          )
        end

        it 'responds with a 200 (OK)' do
          get '/expenses/2017-06-01'
          expect(last_response.status).to eq(200)
        end
      end
    end
```

