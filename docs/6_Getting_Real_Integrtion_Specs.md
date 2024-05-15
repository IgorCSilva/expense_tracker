## Hooking Up the Database

### Getting to Know Sequel
Sequel is a Ruby database library.

Add Sequel and sqlite3 dependencies.

- Gemfile
```rb
gem "sequel", "~> 5.47.0"
gem 'bigdecimal', '~> 3.1', '>= 3.1.4' # maybe this isn't necessary... try without first.
gem "sqlite3", "~> 1.4.3"
```

And run `bundle install`.

### Creating a Database

Create a file:
- config/sequel.rb
```rb
require 'sequel'

DB = Sequel.sqlite("./db/#{ENV.fetch('RACK_ENV', 'development')}.db")
```

This configuration will create a database file such as db/test.db or db/production.db depending on the RACK_ENV environment variable. With this configuration in place, you don’t have to worry about accidentally overwriting your production data during testing.

Now create the migration:
- db/migrations/0001_create_expenses.rb
```rb

Sequel.migration do
  change do
    create_table :expenses do
      primary_key :id
      String :payee
      Float :amount
      Date :date
    end
  end
end
```

And run the migration.
`bundle exec sequel -m ./db/migrations sqlite://db/development.db --echo`

```
...

I, [2024-05-14T20:07:23.261873 #647]  INFO -- : Finished applying migration version 1, direction: up, took 0.006736 seconds
```

## Testing Ledger Behavior

Create a file to implement a hook to make sure the database structure is set up and empty, ready for specs to add data to it.

- spec/support/db.rb
```rb
require_relative '../../config/sequel'

RSpec.configure do |c|
  c.before(:suite) do
    Sequel.extension :migration
    Sequel::Migrator.run(DB, 'db/migrations')
    DB[:expenses].truncate
  end
end
```

First, we run all the migration files in to make sure that all the database tables exist with their current schema. Then, we remove any leftover test data from the table using the truncate method. That way, each run of the spec suite starts with a clean database.

Like `before`, here we define a `suite-level` hook. This one will run just once: after all the specs have been loaded, but before the first one actually runs. That's what before(:suite) hooks are for.

With this, create an integration test file:

- spec/integration/app/ledger.rb
```rb
require_relative '../../../app/ledger'
require_relative '../../../config/sequel'
require_relative '../../support/db'

module ExpenseTracker
  RSpec.describe Ledger do
    let(:ledger) { Ledger.new }
    let(:expense) do
      {
        'payee' => 'Starbucks',
        'amount' => 5.75,
        'date' => '2017-06-01'
      }
    end

    describe '#record' do
      # ... contexts go here ...
    end
  end
end
```

Let's implement the first test.
```rb
    describe '#record' do
      context 'with a valid expense' do
        it 'successfully saves the expense in the DB' do
          result = ledger.record(expense)

          expect(result).to be_success
          expect(DB[:expenses].all).to match [a_hash_including(
            id: result.expense_id,
            payee: 'Starbucks',
            amount: 5.75,
            date: Date.iso8601('2017-06-01')
          )]
        end
      end
    end
```

The matcher `be_success` checks that `result.success?` is true.
The matcher `match [a_hash_including(...)]` expects our app to return data matching a certain structure.

We put two expectations here because the tests with touch database are slower than normal.

Then, run the tests.
`bundle exec rspec spec/integration/app/ledger.rb`

```
Failures:

  1) ExpenseTracker::Ledger#record with a valid expense successfully saves the expense in the DB
     Failure/Error: expect(result).to be_success
       expected nil to respond to `success?`
     # ./spec/integration/app/ledger.rb:21:in `block (4 levels) in <module:ExpenseTracker>'

Finished in 0.04444 seconds (files took 0.24757 seconds to load)
1 example, 1 failure

Failed examples:

rspec ./spec/integration/app/ledger.rb:18 # ExpenseTracker::Ledger#record with a valid expense successfully saves the expense in the DB
```

It's the error from first expect.

Change the example declaration to aggragate errors:
```rb
it 'successfully saves the expense in the DB', :aggregate_failures do
  ...
```

then run tests again.

```
Failures:

  1) ExpenseTracker::Ledger#record with a valid expense successfully saves the expense in the DB
     Got 1 failure and 1 other error:

     1.1) Failure/Error: expect(result).to be_success
            expected nil to respond to `success?`
          # ./spec/integration/app/ledger.rb:21:in `block (4 levels) in <module:ExpenseTracker>'

     1.2) Failure/Error: id: result.expense_id,
          
          NoMethodError:
            undefined method `expense_id' for nil
          # ./spec/integration/app/ledger.rb:23:in `block (4 levels) in <module:ExpenseTracker>'

Finished in 0.02793 seconds (files took 0.18763 seconds to load)
1 example, 1 failure

Failed examples:

rspec ./spec/integration/app/ledger.rb:18 # ExpenseTracker::Ledger#record with a valid expense successfully saves the expense in the DB
```

We want this functionality in each example, then we move this property to the group:

```rb
  RSpec.describe Ledger, :aggregate_failures do
    ...
```

It is seen as a metadata. Internally, RSpec expands this into a hash like `{ aggregate_failures: true }`.

Now, let's fill the Ledger record function.
```rb
    def record(expense)
      DB[:expenses].insert(expense)
      id = DB[:expenses].max(:id)
      RecordResult.new(true, id, nil)
    end
```

Your integration spec should pass now.
To see the data in test.db file inside the db folder, you can use the sqlite-viewer extension(vscode).

## Testing the Invalid Case

Add the context.
```rb
    context 'when the expense lacks a payee' do
      it 'rejects the expense as invalid' do
        
        expense.delete('payee')

        result = ledger.record(expense)

        expect(result).not_to be_success
        expect(result.expense_id).to eq(nil)
        expect(result.error_message).to include('`payee` is required')

        expect(DB[:expenses].count).to eq(0)
      end
    end
```

The test should fail.

## Isolating Your Specs Using Database Transactions

We will wrap each spec in a database transaction.
After each example runs, we want RSpec to rollback the transaction, canceling any writes that happened and leaving the database in a clean state.

Add the code inside the RSpec.configure block:

- spec/support/db.rb
```rb
  c.around(:example, :db) do |example|
    DB.transaction(rollback: :always) { example.run }
  end
```

For each example marked as requiring the database (via the :db tag), the following events happen:

1. RSpec calls our around hook, passing it the example we're running;
2. Inside the hook, we tell Sequel to start a new database transaction;
3. Sequel calls the inner block, in which we tell RSpec to run the example;
4. The body of the example finishes running;
5. Sequel rolls back the transaction, wiping out any changes we made to the database;
6. The around hook finishes, and RSpec moves on to the next example.

Now, add the configuration below, inside the RSpec.configure block, to import file when tests use :db tag:

- spec/spec_helper.rb
```rb
  config.when_first_matching_example_defined(:db) do
    require_relative 'support/db'
  end
```

This way, RSpec will conditionally load `spec/support/db.rb` if any examples are loaded that have a :db tag.

Make the following changes:
- spec/acceptance/expense_tracker_api_spec.rb
```rb
  RSpec.describe 'Expense Tracker API', :db do
    ...
```

- spec/integration/app/ledger.rb
```rb
# REMOVE THIS LINE >> require_relative '../../support/db'

  RSpec.describe Ledger, :aggregate_failures, :db do
    ...
```


## Filling In the Behavior

Check extense structure:
- app/ledger.rb
```rb
  def record(expense)
    unless expense.key?('payee')
      message = 'Invalid expense: `payee` is required'
      return RecordResult.new(false, nil, message)
    end
    
    DB[:expenses].insert(expense)
    id = DB[:expenses].max(:id)
    RecordResult.new(true, id, nil)
  end
```

The tests should pass.

## Querying Expenses

Add query test.
```rb

    describe '#expenses_on' do
      it 'returns all expenses for the provided date' do
        result_1 = ledger.record(expense.merge('date' => '2017-06-10'))
        result_2 = ledger.record(expense.merge('date' => '2017-06-10'))
        result_3 = ledger.record(expense.merge('date' => '2017-06-11'))

        expect(ledger.expenses_on('2017-06-10')).to contain_exactly(
          a_hash_including(id: result_1.expense_id),
          a_hash_including(id: result_2.expense_id)
        )
      end

      it 'returns a blank array when there are no matching expenses' do
        expect(ledger.expenses_on('2017-06-10')).to eq([])
      end
    end
```

Now implement the query in ledger file.

```rb
    def expenses_on(date)
      DB[:expenses].where(date: date).all
    end
```

Now, run all the tests and adjust the results accordingly.
You need to remove the pending command too, from `spec/acceptance/expense_tracker_api_spec.rb`.

At the final, all tests must be pass.

## Ensuring the Application Works for Real

Remove sequel import from `spec/support/db.rb` and put in `app/ledger.rb`.

All tests must keep passing.

Up the API: `bundle exec rackup -o 0.0.0.0`

Then execute the following commands:

`curl localhost:9292/expenses --data '{"payee":"Zoo", "amount":10, "date":"2017-06-01"}' -w "\n"`
{"expense_id":1}

`curl localhost:9292/expenses --data '{"payee":"Starbucks", "amount":7.5, "date":"2017-06-01"}' -w "\n"`
{"expense_id":2}

`curl localhost:9292/expenses/2017-06-01 -w "\n"`
[{"id":1,"payee":"Zoo","amount":10.0,"date":"2017-06-01"},{"id":2,"payee":"Starbucks","amount":7.5,"date":"2017-06-01"}]