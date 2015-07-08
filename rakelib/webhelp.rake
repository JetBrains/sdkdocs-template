directory 'webhelp'
directory 'webhelp/app'
directory 'webhelp/jekyll'

WEBHELP_TEMPLATE_APP_DIR = 'webhelp-template/app'

ICON_FILES = FileList[File.join(WEBHELP_TEMPLATE_APP_DIR, 'favicon.*')]
               .add([File.join(WEBHELP_TEMPLATE_APP_DIR, 'apple-touch-icon*.png')])

ICON_FILES.each do |f|
    target = f.sub(WEBHELP_TEMPLATE_APP_DIR, 'webhelp')
    file target => ['webhelp', f] do
        cp f, target, :verbose => true
    end

    task :prepare_webhelp => target if File.exists?(f)
end

APP_FILES = FileList[File.join(WEBHELP_TEMPLATE_APP_DIR, 'js/main.build.js')]
              .add([File.join(WEBHELP_TEMPLATE_APP_DIR, 'js/vendor/requirejs/require.js')])
              .add([File.join(WEBHELP_TEMPLATE_APP_DIR, 'css/styles.min.css')])
              .add([File.join(WEBHELP_TEMPLATE_APP_DIR, 'fonts/*')])
              .add([File.join(WEBHELP_TEMPLATE_APP_DIR, 'img/svg/*')])
              .add([File.join(WEBHELP_TEMPLATE_APP_DIR, 'templates/page.html')])

APP_FILES.each do |f|
    target = f.sub(WEBHELP_TEMPLATE_APP_DIR, 'webhelp/app')
    dir = File.dirname(target)
    directory dir
    file target => ['webhelp/app', f, dir] do
        cp f, target, :verbose => true
    end

    task :prepare_webhelp => target if File.exists?(f)
end


JEKYLL_FILES = FileList[File.join(WEBHELP_TEMPLATE_APP_DIR, 'templates/page.html')]

JEKYLL_FILES.each do |f|
    target = f.sub(WEBHELP_TEMPLATE_APP_DIR, 'webhelp/jekyll')
    dir = File.dirname(target)
    directory dir
    file target => ['webhelp/jekyll', f, dir] do
        cp f, target, :verbose => true
    end

    task :prepare_webhelp => target if File.exists?(f)
end

# Because webhelp-template is currently a private repo, we need to
# maintain a copy of the compiled app files (icons, css, js). The
# files are copied into the site by the default config.yml
# TODO: Should this also build the webhelp-template?
desc 'Copies the precompiled webhelp-template files'
task :prepare_webhelp
