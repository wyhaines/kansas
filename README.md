# Kansas

Kansas is an object-releational mapping library for Ruby. It has been around and in use since 2004 in many production projects, but has received very little open source exposure in that time, being used almost exclusively in closed source commercial projects.

Kansas's original design leveraged DBI, and provided an ORM mapping with a ruby based query syntax.

I am putting it on github, and starting the repo with a version of kansas from circa 2006-2007ish times. It will then be updated with a somewhat newer version that implements a few minor changes. The library will be converted to a modern Ruby packaging structure, and modernized.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'kansas'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install kansas

## Usage

With Kansas, queries are built using Ruby code, with some concessions to syntax because some Ruby operations are implemented as keywords, such as '&&', and thus can't be co-opted, while '&' is simply a method, and can be.

```ruby
ksdbh = KSDatabase.new("dbi:Mysql:DBNAME:DBHOST", USERNAME, PASSWORD)
ksdbh.map_all_tables
```

```ruby
# Equivalent to:
#     select * from table_as_classname
all_rows = ksdbh.select(:TableAsClassname)
```

```ruby
# Equivalent to:
#     select * from table_as_classname where field = "blah"
some_rows = ksdbh.select(:TableAsClassname) {|t| t.field == "blah"}
```

```ruby
# Equivalent to:
#     select * from table table_as_classname where field = "blah" and field2 > 100 and field3 between(3,6)
some_rows = ksdbh.select(:TableAsClassname) do |t|
  ( t.field == "blah" ) &
  ( t.field2 > 100 ) &
  ( t.field3.between(3,6) )
end
```

```ruby
first_record = some_rows.first
# Unless autocommit is set to false, this will update the database synchronously
first_record.field4 = "more stuff"
```

```ruby
# Implied transactions
ksdbh.autcommit = false
first_record.field = "bleargh"
first_record.field2 = 1000
$ksdbh.commit # use ksdbh.rollback to revert the changes, instead
```

```ruby
# Explicit transitions via a block
ksdbh.transaction do
  first_record.field3 = "xyzzy"
  first_record.field4 = do_calculation

  if first_record.field4 < 100
    ksdbh.rollback
  else
    ksdbh.commit
  end
end
```

```ruby
# Delete a record
first_record.delete
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wyhaines/kansas. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

