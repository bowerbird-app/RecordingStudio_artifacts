# frozen_string_literal: true

return if ENV["DISABLE_SIMPLECOV"] == "true"

begin
  require "simplecov"
rescue LoadError
  return
end

SimpleCov.start do
  enable_coverage :branch
  cover "{app,lib}/**/*.rb"
  skip "/test/"
  skip "/config/"
  skip "/db/"
  minimum_coverage line: 94
end
