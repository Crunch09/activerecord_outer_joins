Adds an `outer_joins` method to `ActiveRecord`.

## Installation
Just put it in your `Gemfile`
```ruby
gem 'activerecord_outer_joins'
```
Then run `bundle install`.

## Example
```ruby
User.outer_joins(:posts)
# => SELECT "users".* FROM "users" LEFT OUTER JOIN "posts" ON "posts"."user_id" = "users"."id"
```

This project rocks and uses MIT-LICENSE.
