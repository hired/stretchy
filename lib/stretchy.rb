require 'json'
require 'logger'
require 'forwardable'
require 'excon'
require 'elasticsearch'
require 'virtus'
require 'validation'

require 'stretchy_validations'
require 'stretchy/boosts'
require 'stretchy/builders'
require 'stretchy/clauses'
require 'stretchy/errors'
require 'stretchy/filters'
require 'stretchy/queries'
require 'stretchy/results'
require 'stretchy/types'
require 'stretchy/utils'
require 'stretchy/version'

# {include:file:README.md}

module Stretchy
  extend Stretchy::Utils::Configuration
  extend Stretchy::Utils::ClientActions
end
