ENV["path"] += ";d:\\\portableGit\\bin" # acces au git local à la machine qui execute ce script
set :branch, "master" # version à déployer
set :application, "scraperbot" # nom application (github)
set :keep_releases, 3 # nombre de version conservées
set :server_name, "192.168.1.53" # adresse du server de destination
set :repository, "https://github.com/devscrapper/#{application}.git" # adresse du referentiel de la l'application sous github
set :deploy_to, "/home/eric/www/#{application}" # repertoire de deploiement de l'application
set :scm, "git"
set :deploy_via, :copy
set :rvm_type, :user
set :rvm_ruby_string, :release_path
set :user, "eric"
set :password, "Brembo01"
default_run_options[:pty] = true
set :use_sudo, false
set :server_list, ["authentification", "calendar", "ftpd" , "scraper"]
role :app, server_name

require "rvm/capistrano"

depend :remote, :gem, "eventmachine", ">=1.0.0"
depend :remote, :gem, "certified", ">=0.1.1"
depend :remote, :gem, "em-http-request", ">=1.0.3"
depend :remote, :gem, "domainatrix", ">=0.0.10"
depend :remote, :gem, "nokogiri", ">=1.5.5"
depend :remote, :gem, "json", ">=1.7.5"
depend :remote, :gem, "em-ftpd", ">=0.0.1"
depend :remote, :gem, "google-api-client", ">=0.4.6"
depend :remote, :gem, "rufus-scheduler", ">=2.0.17"
depend :remote, :gem, "ice_cube", ">=0.9.3"
depend :remote, :gem, "logging", ">=1.8.1"
depend :remote, :gem, "rest-client", ">=1.6.7"


after "deploy:update", "customize:update"
after "deploy:bundle", "customize:bundle"
after "deploy:setup", "customize:setup"
set :envir, "test"

namespace :machine do
  task :reboot, :roles => :app do
    run "#{sudo} reboot"
  end
end
namespace :deploy do
  task :bundle, :roles => :app do
    run "cd #{deploy_to}/current && bundle install --without development --deployment"
  end
  task :start, :roles => :app, :except => {:no_release => true} do
    server_list.each{|server| run "#{sudo} initctl start #{server}"}

  end
  task :stop, :roles => :app, :except => {:no_release => true} do
    server_list.each{|server| run "#{sudo} initctl stop #{server}"}
  end
  task :restart, :roles => :app, :except => {:no_release => true} do
    server_list.each{|server| run "#{sudo} initctl stop #{server}"}
    server_list.each{|server| run "#{sudo} initctl start #{server}"}
  end
end

namespace :customize do
  task :setup do
    run "mkdir -p #{File.join(deploy_to, "shared", "data")}"
    run "mkdir -p #{File.join(deploy_to, "shared", "output")}"
    end
  task :update do
    server_list.each{|server|  run "#{sudo} rm --interactive=never -f /etc/init/#{server}.conf && #{sudo} cp #{File.join(current_path, "control", "#{server}.conf")} /etc/init"}
    run "echo 'staging: test' >  #{File.join(current_path, 'parameter', 'environment.yml')}"
    run "ln -s #{File.join(deploy_to, "shared", "data")} #{File.join(current_path, "data")}"
    run "ln -s #{File.join(deploy_to, "shared", "output")} #{File.join(current_path, "output")}"
  end
  task :bundle do

  end
end
# ordre de lancement des commandes deploy :
# first deploy
# 1 deploy:check     # controle que l'environement hebergeur est ok
# 2 deploy:setup     # realise les adaptations sur l'environnement
# 3 deploy:update    # deploie les sources
# 4 deploy:bundle     # deploie les gem pre requis
# 5 deploy:start     # demarre les serveurs


# next deploy
# 1 deploy:stop     # stoppe les serveurs
# 2 deploy:check     # controle que l'environement hebergeur est ok
# 3 deploy:setup     # realise les adaptations sur l'environnement
# 4 deploy:update    # deploie les sources
# 5 deploy:bundle    # deploie les gem pre requis
# 6 deploy:start     # demarre les serveurs

