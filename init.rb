require 'redmine'

if Rails::VERSION::MAJOR < 3
  require 'dispatcher'
  object_to_prepare = Dispatcher
else
  object_to_prepare = Rails.configuration
  # if redmine plugins were railties:
  # object_to_prepare = config
end

object_to_prepare.to_prepare do #:bsd_backlogs do
  require_dependency 'issue'
  #Guards against including the module multiple time (like in tests)
  #and registering multiple callbacks
  unless Issue.included_modules.include? BSDBacklogs::IssuePatch
    Issue.send(:include, BSDBacklogs::IssuePatch)
  end
end

Redmine::Plugin.register :bsd_backlogs do
  name 'BSD Backlogs plugin'
  author 'Alex Graham'
  description 'Optionally enforce a unique number on ticket on a per project basis.'
  version '1.0.0'
  url 'http://github.com/alexgrahamuk/bsd_backlogs'
  author_url 'http://www.ncl.ac.uk/itservice/'

  requires_redmine :version_or_higher => '0.8.0'
end
