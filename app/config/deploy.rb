set :application, "WebIDE"
set :serverName, "webide.co"
set :domain,     "webide.co"

set :deploy_to,     "/var/www/#{domain}/"
set :app_path,    "app"

#set :repository,   "file:///var/www/webide"
set :repository,   "git@webide.co:webide.git"
set :scm,          :git
set :deploy_via,   :rsync_with_remote_cache

set :user, "deployer"

role :web,        domain
role :app,        domain
role :db,         domain, :primary => true

set :model_manager, "doctrine"
set :keep_releases,  3
set :use_sudo,      false
set :use_composer, true
set :vendors_mode, "install"
set :maintenance_template_path, app_path + "/maintenance.erb"

default_run_options[:pty] = true

# Set some paths to be shared between versions
set :shared_files,    ["app/config/parameters.yml", "vendor"]
set :shared_children, [app_path + "/logs", web_path + "/uploads"]
set :asset_children,   [web_path + "/css", web_path + "/js"]

# Change ACL on the app/logs and app/cache directories
after 'deploy:finalize_update', 'deploy:update_acl'

# This is a custom task to set the ACL on the app/logs and app/cache directories
namespace :deploy do

  task :update_acl, :roles => :app do
    writable_dirs = [
        app_path + "/logs",
        app_path + "/cache"
    ]

    # Allow directories to be writable by webserver and this user
    run "cd #{latest_release} && setfacl -R -m u:www-data:rwx -m u:#{user}:rwx #{writable_dirs.join(' ')}"
    run "cd #{latest_release} && setfacl -dR -m u:www-data:rwx -m u:#{user}:rwx #{writable_dirs.join(' ')}"
  end

  namespace :web do
    desc <<-DESC
      Present a maintenance page to visitors. Disables your application's web \
      interface by writing a "#{maintenance_basename}.html" file to each web server. The \
      servers must be configured to detect the presence of this file, and if \
      it is present, always display it instead of performing the request.

      By default, the maintenance page will just say the site is down for \
      "maintenance", and will be back "shortly", but you can customize the \
      page by specifying the REASON and UNTIL environment variables:

        $ cap deploy:web:disable \\
              REASON="hardware upgrade" \\
              UNTIL="12pm Central Time"

      You can use a different template for the maintenance page by setting the \
      :maintenance_template_path variable in your deploy.rb file. The template file \
      should either be a plaintext or an erb file.

      Further customization will require that you write your own task.
    DESC
    task :disable, :roles => :web, :except => { :no_release => true } do
      require 'erb'
      on_rollback { run "rm #{latest_release}/#{web_path}/#{maintenance_basename}.html" }

      reason   = ENV['REASON']
      deadline = ENV['UNTIL']
      template = File.read(maintenance_template_path)
      result   = ERB.new(template).result(binding)

      put result, "#{latest_release}/#{web_path}/#{maintenance_basename}.html", :mode => 0644
    end

    desc <<-DESC
      Makes the application web-accessible again. Removes the \
      "#{maintenance_basename}.html" page generated by deploy:web:disable, which (if your \
      web servers are configured correctly) will make your application \
      web-accessible again.
    DESC
    task :enable, :roles => :web, :except => { :no_release => true } do
      run "rm #{latest_release}/#{web_path}/#{maintenance_basename}.html"
    end
  end
end