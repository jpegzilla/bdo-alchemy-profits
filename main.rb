# frozen_string_literal: true

require_relative 'lib/bdo_alchemy_profits'

profit_calculator = BDOAP::BDOAlchemyProfits.new

profit_calculator.start_cli
