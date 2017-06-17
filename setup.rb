#!/usr/bin/env ruby
# frozen_string_literal: true

require 'logger'
require_relative 'agent'

LOGGER = Logger.new(STDERR)

agent = Agent.new(LOGGER)
agent.run
