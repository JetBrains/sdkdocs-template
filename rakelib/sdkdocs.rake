require 'erb'
require 'pathname'

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
  sh "bundle install --path sdkdocs-template/_vendor/bundle"
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
file '_includes/page.html' => [ '_includes', "#{@relative_dir}/webhelp/jekyll/templates/page.html" ] do |t|
  cp t.prerequisites[1], t.name, :verbose => true
end

task :prepare_jekyll_includes => '_includes/page.html'

desc 'Ensure assets are in the right place for a build'
task :prepare_assets => [:prepare_config_defaults, :prepare_webhelp, :prepare_jekyll_includes]

desc 'Build the site, without starting the server.'
task :build => :prepare_assets do
  dest = ENV['dest'] || CONFIG[:build_destination]

  sh "bundle exec jekyll build --trace --config #{@relative_dir}/jekyll/_config-defaults.yml,_config.yml --destination=#{dest}"
end

desc 'Builds and hosts the site.'
task :preview => :prepare_assets do
  host = ENV['host'] || CONFIG[:preview_host]
  port = ENV['port'] || CONFIG[:preview_port]
  dest = ENV['dest'] || CONFIG[:build_destination]

  # Force polling is more CPU intensive, but more accurate on Windows
  force_polling = '--force_polling ' if RUBY_PLATFORM =~ /win32/

  sh "bundle exec jekyll serve --trace --config #{@relative_dir}/jekyll/_config-defaults.yml,_config.yml --host=#{host} --port=#{port} #{force_polling} --destination=#{dest}"

end

desc 'Check all links'
task :links => :build do
  dest = ENV['dest'] || CONFIG[:build_destination]

  # It would be nice to just require 'bundler/setup' and require 'link_checker' and then
  # `LinkChecker.new(:target => "#{dest}").check_uris`, but that requires running
  # `bundle exec rake` rather than just `rake`. Let's keep it easy...
  sh "bundle exec check-links #{dest}"
end
