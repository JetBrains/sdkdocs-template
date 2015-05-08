# Shamelessly stolen and tweaked from https://github.com/chikathreesix/jekyll-gh-pages
require 'fileutils'

remote_name = ENV.fetch("REMOTE_NAME", "origin")
branch_name = ENV.fetch("BRANCH_NAME", "gh-pages")

PROJECT_ROOT = `git rev-parse --show-toplevel`.strip
BUILD_DIR    = File.join(PROJECT_ROOT, "_gh_pages")
GH_PAGES_REF = File.join(BUILD_DIR, ".git/refs/remotes/#{remote_name}/#{branch_name}")

directory BUILD_DIR

file GH_PAGES_REF => BUILD_DIR do
  repo_url = nil

  cd PROJECT_ROOT do
    repo_url = `git config --get remote.#{remote_name}.url`.strip
  end

  cd BUILD_DIR do
    sh "git init"
    sh "git remote add #{remote_name} #{repo_url}"
    sh "git fetch #{remote_name}"

    if `git branch -r` =~ /#{branch_name}/
      sh "git checkout #{branch_name}"
    else
      sh "git checkout --orphan #{branch_name}"
      sh "touch index.html"
      sh "git add ."
      sh "git commit -m 'initial #{branch_name} commit'"
      sh "git push #{remote_name} #{branch_name}"
    end
  end
end

desc "Prepare for build"
task :prepare_gh_pages => GH_PAGES_REF

task :gh_pages_env do
    ENV["dest"] = BUILD_DIR
end

desc "Deploy static files to gh-pages branch"
task :gh_pages => [:gh_pages_env, :build] do
  message = nil
  suffix = ENV["COMMIT_MESSAGE_SUFFIX"]

  cd PROJECT_ROOT do
    head = `git log --pretty="%h" -n1`.strip
    message = ["Site updated to #{head}", suffix].compact.join("\n\n")
  end

  cd BUILD_DIR do
    sh 'git add --all'
    if /nothing to commit/ =~ `git status`
      puts "No changes to commit."
    else
      sh "git commit -m \"#{message}\""
    end
    sh "git push #{remote_name} #{branch_name}"
  end
end
