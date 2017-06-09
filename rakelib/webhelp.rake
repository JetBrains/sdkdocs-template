directory 'webhelp'
directory 'webhelp/app'
directory 'webhelp/jekyll'

WEBHELP_TEMPLATE_BUILD_DIR = 'webhelp-template/build'

APP_FILES = FileList[File.join(WEBHELP_TEMPLATE_BUILD_DIR, 'app.*')]

APP_FILES.each do |f|
    target = f.sub(WEBHELP_TEMPLATE_BUILD_DIR, 'webhelp/app')
    dir = File.dirname(target)
    directory dir
    file target => ['webhelp/app', f, dir] do
        cp f, target, :verbose => true
    end

    task :prepare_webhelp => target if File.exists?(f)
end

# Because webhelp-template is currently a private repo, we need to
# maintain a copy of the compiled app files (css, js). The
# files are copied into the site by the default config.yml
desc 'Copies the precompiled webhelp-template files'
task :prepare_webhelp
