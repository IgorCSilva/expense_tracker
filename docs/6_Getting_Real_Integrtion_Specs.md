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