require_relative 'app/api'
require_relative 'app/ledger'

run ExpenseTracker::API.new(ExpenseTracker::Ledger.new)