# frozen_string_literal: true

require_relative './utils/user_cli'

cli = UserCLI.new

category = cli.ask

cli.stop
