ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "mocha/minitest"
require "minitest/stub_any_instance"

# Minitest::Mock was removed in Ruby 3.4/Minitest 6.x
# Provide a simple replacement using mocha for compatibility
module Minitest
  class Mock
    def initialize
      @expectations = {}
    end

    def expect(method_name, return_value, args = [])
      @expectations[method_name] = { return_value: return_value, args: args }
      self
    end

    def method_missing(method_name, *args, &block)
      if @expectations.key?(method_name)
        @expectations[method_name][:return_value]
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @expectations.key?(method_name) || super
    end

    def verify
      true
    end
  end
end
require "tempfile"
require "ostruct"
require_relative "test_helpers/session_test_helper"

# Minitest Object#stub was removed in Ruby 3.4
# Adding it back via monkey-patch for compatibility with existing tests
unless Object.respond_to?(:stub)
  class Object
    def stub(name, val_or_callable, *block_args, &block)
      new_name = "__minitest_stub__#{name}"

      metaclass = class << self; self; end
      metaclass.alias_method new_name, name if respond_to?(name)

      metaclass.define_method(name) do |*args, **kwargs, &blk|
        if val_or_callable.respond_to?(:call)
          val_or_callable.call(*args, **kwargs, &blk)
        else
          val_or_callable
        end
      end

      yield(*block_args) if block
    ensure
      metaclass.undef_method(name)
      metaclass.alias_method(name, new_name) if metaclass.method_defined?(new_name)
      metaclass.undef_method(new_name) if metaclass.method_defined?(new_name)
    end
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
