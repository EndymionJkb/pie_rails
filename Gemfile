source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.5.8'

gem 'rails', '5.2.4.2'
# Use postgresql as the database for Active Record
gem 'pg', '1.2.3'
# Use Puma as the app server
gem 'puma', '4.3.12'
# Use SCSS for stylesheets
gem 'sassc-rails', '2.1.2'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '4.2.0'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'mini_racer', platforms: :ruby
gem 'devise', '4.7.1'
gem 'bcrypt', '3.1.13'
gem 'jquery-rails', '4.3.5'
gem 'jquery-ui-rails', '6.0.1'
gem 'bootstrap', '4.4.1'
gem 'haml', '5.1.2'
gem 'will_paginate', '3.3.0'
gem 'web3-eth', '0.2.38'

gem 'bootsnap', '>= 1.1.0', require: false

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'rspec-rails', '4.0.0'
  gem 'factory_bot_rails', '5.1.1'
  gem 'faker', '2.11.0'
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'rb-readline', '0.5.5'
  gem 'annotate', '3.1.1'
  gem 'haml-rails', '2.0.1'
  gem 'better_errors', '2.8.0'
  gem 'binding_of_caller', '0.8.0'
end

group :test do
  gem 'database_cleaner-active_record', '1.8.0'
  gem 'shoulda-matchers', '4.3.0'
  gem 'rspec-its', '1.3.0'  
end
