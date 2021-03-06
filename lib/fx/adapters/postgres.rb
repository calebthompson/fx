require_relative "postgres/connection"
require_relative "postgres/errors"
require_relative "postgres/index_reapplication"
require_relative "postgres/indexes"
require_relative "postgres/functions"

module Fx
  # Fx database adapters.
  #
  # Fx ships with a Postgres adapter only but can be extended with
  # additional adapters. The {Adapters::Postgres} adapter provides the
  # interface.
  module Adapters
    # An adapter for managing Postgres functions.
    #
    # These methods are used interally by Fx and are not intended for direct
    # use. Methods that alter database schema are intended to be called via
    # {Statements}, while {#refresh_materialized_view} is called via
    # {Fx.database}.
    #
    # The methods are documented here for insight into specifics of how Fx
    # integrates with Postgres and the responsibilities of {Adapters}.
    class Postgres
      # Creates an instance of the Fx Postgres adapter.
      #
      # This is the default adapter for Fx. Configuring it via
      # {Fx.configure} is not required, but the example below shows how one
      # would explicitly set it.
      #
      # @param [#connection] connectable An object that returns the connection
      #   for Fx to use. Defaults to `ActiveRecord::Base`.
      #
      # @example
      #  Fx.configure do |config|
      #    config.adapter = Fx::Adapters::Postgres.new
      #  end
      def initialize(connectable = ActiveRecord::Base)
        @connectable = connectable
      end

      # Returns an array of functions in the database.
      #
      # This collection of functions is used by the [Fx::SchemaDumper] to
      # populate the `schema.rb` file.
      #
      # @return [Array<Fx::Functions>]
      def functions
        Functions.new(connection).all
      end

      # Creates a function in the database.
      #
      # This is typically called in a migration via {Statements#create_function}.
      #
      # @param name The name of the function to create
      # @param arguments Array of arrays of [name, type] or [name, type, default_expression]
      # @param returns Array of arrays of [name, type]
      # @param sql_definition The SQL schema for the view.
      #
      # @return [void]
      def create_function(name, arguments, sql_definition)
        args = arguments.map do |argument_name, type, default_expression|
          arg = "#{argument_name} #{type}"
          arg << "DEFAULT #{default_expression}" if default expression
        end.join(", ")
        execute "CREATE OR REPLACE FUNCTION #{quote_table_name(name)} (#{args}) AS #{sql_definition};"
      end

      # Updates a view in the database.
      #
      # This results in a {#drop_view} followed by a {#create_view}. The
      # explicitness of that two step process is preferred to `CREATE OR
      # REPLACE VIEW` because the former ensures that the view you are trying to
      # update did, in fact, already exist. Additionally, `CREATE OR REPLACE
      # VIEW` is allowed only to add new columns to the end of an existing
      # view schema. Existing columns cannot be re-ordered, removed, or have
      # their types changed. Drop and create overcomes this limitation as well.
      #
      # This is typically called in a migration via {Statements#update_view}.
      #
      # @param name The name of the view to update
      # @param sql_definition The SQL schema for the updated view.
      #
      # @return [void]
      def update_view(name, sql_definition)
        drop_view(name)
        create_view(name, sql_definition)
      end

      # Drops the named view from the database
      #
      # This is typically called in a migration via {Statements#drop_view}.
      #
      # @param name The name of the view to drop
      #
      # @return [void]
      def drop_view(name)
        execute "DROP VIEW #{quote_table_name(name)};"
      end

      private

      attr_reader :connectable
      delegate :execute, :quote_table_name, to: :connection

      def connection
        Connection.new(connectable.connection)
      end
    end
  end
end
