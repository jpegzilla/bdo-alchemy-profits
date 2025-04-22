# frozen_string_literal: true

desc 'install dependencies'
task :install do
  puts
  puts 'installing dependencies...'
  system 'bundle install'
end

task :clean do
  puts
  puts 'cleaning dependencies...'
  system "bundle clean #{ARGV.slice 1}"
end

desc 'check dependencies'
task :check_deps do
  puts
  puts 'checking dependencies...'
  result = system 'bundle check'

  system('rake install') unless result == true
end

desc 'start script'
task start: [:check_deps] do
  puts
  system "ruby main.rb #{ARGV.slice 1}"
end

desc 'package gem'
task pack: [:check_deps] do
  puts
  puts 'building gem...'
  puts
  system 'gem build bdo-alchemy-profits.gemspec'
end
