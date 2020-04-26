require "fileutils"
require "shellwords"

TEMPLATE="https://gitlab.com/omnicode.solutions/omnistart.git"

# Copied from: https://github.com/mattbrictson/rails-template
# Add this template directory to source_paths so that Thor actions like
# copy_file and template resolve against our source files. If this file was
# invoked remotely via HTTP, that means the files are not present locally.
# In that case, use `git clone` to download them to a local temporary dir.
def add_template_repository_to_source_path
  if __FILE__ =~ %r{\Ahttps?://}
    require "tmpdir"
    source_paths.unshift(tempdir = Dir.mktmpdir("omnistart-"))
    at_exit { FileUtils.remove_entry(tempdir) }
    git clone: [
      "--quiet",
      TEMPLATE,
      tempdir
    ].map(&:shellescape).join(" ")

    if (branch = __FILE__[%r{omnistart/(.+)/template.rb}, 1])
      Dir.chdir(tempdir) { git checkout: branch }
    end
  else
    source_paths.unshift(File.dirname(__FILE__))
  end
end

def rails_version
  @rails_version ||= Gem::Version.new(Rails::VERSION::STRING)
end

def rails_6?
  Gem::Requirement.new(">= 6.0.0.beta1", "< 7").satisfied_by? rails_version
end

def add_gems
  gem 'standard'
  gem 'devise', '~> 4.7', '>= 4.7.0'
end

def set_application_name
  # Add Application Name to Config
  environment "config.application_name = Rails.application.class.module_parent_name"

  # Announce the user where he can change the application name in the future.
  puts "You can change application name inside: ./config/application.rb"
end

def stop_spring
  run "spring stop"
end

def copy_templates
  directory "db", force: true
end

def standardize
  rails_command "standard:fix"
end

# Main setup
unless rails_6?
  say "omnistart app template cannot be created. Use rails 6!", :blue
  exit
end

add_template_repository_to_source_path

add_gems

after_bundle do
  set_application_name
  stop_spring

  copy_templates
  standardize

  # Migrate
  rails_command "db:create"
  rails_command "db:migrate"

  # Commit everything to git
  git :init
  git add: "."
  git commit: %Q{ -m 'Initial commit' }

  say
  say "omnistart app successfully created!", :blue
  say
  say "To get started with your new app:", :green
  say "cd #{app_name} - Switch to your new app's directory."
end
