require 'erb'
require 'pathname'
require 'link_checker' if ENV.has_key?('BUNDLER_VERSION')

dir = Pathname.new("#{__dir__}/..").cleanpath
relative_dir = dir.relative_path_from(Pathname.new(Dir.pwd))
@root_dir = dir.to_s
@relative_dir = relative_dir.to_s

task :default do
  system('rake -T')
end

desc 'Bootstraps the build environment with bundler. Only needed to run once.'
task :bootstrap do
  RakeFileUtils.cp 'sdkdocs-template/bundler/Gemfile.template', 'Gemfile' unless File.exists?('Gemfile')
  sh "gem install bundler && bundle install --path ~/.bundles/sdkdocs-template/_vendor/bundle"
end

task :prepare_config_defaults do
  # Set up env var for the config template. Allows us to specify the location
  # of the jekyll files in the sdkdocs-template folder relative to the base folder
  ENV['_sdkdocs_template_dir'] = @root_dir

  ENV['_sdkdocs_static_files_dir'] = relative_dir.join('webhelp').to_s

  template = ERB.new File.new("#{@relative_dir}/jekyll/config-defaults.yml.erb").read
  File.open("#{@relative_dir}/jekyll/_config-defaults.yml", 'w') do |f|
    f.write template.result(binding)
  end
end

directory '_includes'
file '_includes/page.html' => [ '_includes', "#{@relative_dir}/jekyll/templates/page.html" ] do |t|
  cp t.prerequisites[1], t.name, :verbose => true
end

task :prepare_jekyll_includes => '_includes/page.html'

desc 'Ensure assets are in the right place for a build'
task :prepare_assets => [:prepare_config_defaults, :prepare_webhelp, :prepare_jekyll_includes]

desc 'Build the site, without starting the server.'
task :build, [:configyml] => :prepare_assets do |t, args|
  args.with_defaults(:configyml => '_config.yml')
  dest = ENV['dest'] || CONFIG[:build_destination]

  sh "bundle exec jekyll build --trace --config #{@relative_dir}/jekyll/_config-defaults.yml,#{args[:configyml]} --destination=#{dest}"
end

desc 'Builds and hosts the site.'
task :preview => :prepare_assets do
  host = ENV['host'] || CONFIG[:preview_host]
  port = ENV['port'] || CONFIG[:preview_port]
  dest = ENV['dest'] || CONFIG[:build_destination]

  # Are we running inside docker?
  docker = ENV['DOCKER'] == 'true'

  # Force polling is more CPU intensive, but more accurate on Windows
  # It's also required if we're running in docker, since we're sharing the app folder
  # Note that the TC build calls rake build, so this won't affect a build
  force_polling = '--force_polling ' if RUBY_PLATFORM =~ /win32/ or docker

  sh "bundle exec jekyll serve --trace --incremental --config #{@relative_dir}/jekyll/_config-defaults.yml,_config.yml --host=#{host} --port=#{port} #{force_polling} --destination=#{dest}"

end

# This is lazy. We should really be calling `bundle exec rake ...` at all times,
# but that's a bit inconvenient. The only time we actually need to do this is
# for link checking, because we're using a gem that bundle brings in for us
task :requires_bundle_exec_rake do
  raise "Run 'bundle exec rake {args}'" unless ENV.has_key?('BUNDLER_VERSION')
end

desc 'Check all links'
task :links => [:requires_bundle_exec_rake, :build] do
  dest = ENV['dest'] || CONFIG[:build_destination]

  success = LinkChecker.new(:options => {
    :no_warnings => true,
    :exclusions => [
        %r!^https?://github.com/[^/]+/[^/]+/edit/!,
        %r!^https?://plugins.jetbrains.com/plugins/list!,
        %r!^https?://plugins.jetbrains.com/plugin/developers!,
        %r!^https?://plugins.jetbrains.com/plugin/download!,
        %r!^https?://plugins.jetbrains.com/author/me!,
        %r!^https?://localhost:4000/intellij/sdk/docs/$!,
    ],
    :no_info => true
  }, :target => dest).check_uris

  raise "Errors found in links" if success > 0
end
