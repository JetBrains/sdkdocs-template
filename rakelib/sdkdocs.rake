require 'erb'
require 'pathname'

task :default do
  system('rake -T')
end

desc 'Bootstraps the build environment with bundler. Only needed to run once.'
task :bootstrap => [:prepare_env] do
  RakeFileUtils.cp 'sdkdocs-template/bundler/Gemfile.template', 'Gemfile' unless File.exists?('Gemfile')
  sh "bundle install --path sdkdocs-template/_vendor/bundle"
end

desc ''
task :prepare_env do
  dir = Pathname.new("#{__dir__}/..").cleanpath
  relative_dir = dir.relative_path_from(Pathname.new(Dir.pwd))
  @root_dir = dir.to_s
  @relative_dir = relative_dir.to_s

  # Set up env var for the config template. Allows us to specify the location
  # of the jekyll files in the sdkdocs-template folder relative to the base folder
  ENV['_sdkdocs_template_dir'] = @root_dir

  ENV['_sdkdocs_static_files_dir'] = relative_dir.join('webhelp').to_s

  template = ERB.new File.new("#{@relative_dir}/jekyll/config-defaults.yml.erb").read
  File.open("#{@relative_dir}/jekyll/_config-defaults.yml", 'w') do |f|
    f.write template.result(binding)
  end
end

desc 'Ensure assets are in the right place for a build'
task :prepare_assets => [:prepare_env, :prepare_webhelp] do
  # Copy _includes/page.html to the site source. Jekyll doesn't allow us to move this
  RakeFileUtils.mkdir_p '_includes'
  RakeFileUtils.cp "#{@relative_dir}/webhelp/jekyll/page.html", '_includes/page.html'
end

desc 'Build the site, without starting the server.'
task :build => [:prepare_env, :prepare_assets] do
  dest = ENV['dest'] || CONFIG[:build_destination]

  sh "bundle exec jekyll build --trace --config #{@relative_dir}/jekyll/_config-defaults.yml,_config.yml --destination=#{dest}"
end

desc 'Builds and hosts the site.'
task :preview => [:prepare_env, :prepare_assets] do
  host = ENV['host'] || CONFIG[:preview_host]
  port = ENV['port'] || CONFIG[:preview_port]
  dest = ENV['dest'] || CONFIG[:build_destination]

  # Force polling is more CPU intensive, but more accurate on Windows
  force_polling = '--force_polling ' if RUBY_PLATFORM =~ /win32/

  sh "bundle exec jekyll serve --trace --config #{@relative_dir}/jekyll/_config-defaults.yml,_config.yml --host=#{host} --port=#{port} #{force_polling} --destination=#{dest}"

end

