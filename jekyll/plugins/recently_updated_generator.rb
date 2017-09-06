require 'yaml'
require 'json'
require 'kramdown'

class RecentsPage < Jekyll::Page
  # Initialize a new RecentsPage.
  #
  # site - The Site object.
  # base - The String path to the source.
  # dir  - The String path between the source and the file.
  # name - The String filename of the file.
  def initialize(site, base, dir, name, content, data)
    @site = site
    @base = base
    @dir = dir
    @name = name
    @content = @output = content

    self.process(name)
    self.data = data
  end
end

class RecentsGenerator < Jekyll::Generator

  def generate(site)
    raise "Git is not installed" unless git_installed?

    recents_output = site.config['recently_updated_output'] || 'recently_updated.md'
    data = site.frontmatter_defaults.all(recents_output, :pages).clone
    data['title'] = 'Recently Updated'
    data['edit_on_github'] = false

    pages_by_path = Hash.new
    site.pages.each { |p| pages_by_path[p.path] = p }

    github_repo = site.config['github_repo']
    youtrack_project = site.config['youtrack_project']
    content = header(github_repo)
    content << format_commits(commits, github_repo, youtrack_project, pages_by_path)
    #content << commits.to_s

    recents_page = RecentsPage.new(site, site.source, '/', recents_output, content, data)
    site.pages << recents_page
  end

  def header(github_repo)
    "See the [full changelog on GitHub](https://github.com/#{github_repo}/commits/)\n"
  end

  def format_commits(commits, github_repo, youtrack_project, pages_by_path)
    content = ''

    prev_date = ''
    commits.each do |c|

      if c[:files].any? {|f| f[:file] != '_SUMMARY.md' && f[:file].end_with?(".md")}

        date = c[:date].strftime('%-d %B %Y')
        content << "<hr>\n## #{date}\n" unless date == prev_date
        content << "\n"
        content << "**#{format_message(c[:subject], github_repo, youtrack_project)}** ([view diff](https://github.com/#{github_repo}/commit/#{c[:hash]}))\n"
        body = c[:body].join()
        content << "<br>#{format_message(body, github_repo, youtrack_project)}\n"

        content << "\n"
        c[:files].each do |f|
          file = f[:file]
          if file != '_SUMMARY.md' and file.end_with?('.md') then
            case f[:type]
            when 'D'
              content << "* `#{file}` (deleted)\n"
            when 'R'
                newfile = f[:newfile]
                title = pages_by_path.key?(newfile) ? pages_by_path[newfile].data['title'] : newfile
                content << "* [#{title}](/#{newfile}) (renamed from `#{file}`)\n"
            else
              title = pages_by_path.key?(file) ? pages_by_path[file].data['title'] : file
              content << "* [#{title}](/#{file})\n"
            end
          end
        end
        content << "\n"

        prev_date = date
      end
    end

    content
  end

  def format_message(msg, github_repo, youtrack_project)
    msg = msg.gsub(/(\#(\d+))/, "[\\1](https://github.com/#{github_repo}/issues/\\2)")
    if youtrack_project then
      msg = msg.gsub(/(#{youtrack_project}-\d+)/, "[\\1](https://youtrack.jetbrains.com/issue/\\1)")
    end
    msg
  end

  def commits
    commits = []
    lines = %x{ git log -n50 --no-merges --name-status --pretty=format:%H%n%an%n%aD%n%s%n%b%n%n }
    lines = lines.lines
    i = 0
    while lines.length > 0 do
      commit = {
        :hash => lines.shift.strip,
        :author => lines.shift.strip,
        :date => DateTime.parse(lines.shift.strip),
        :subject => lines.shift.strip
      }

      body = [ lines.shift.strip ]
      line = ''
      begin
        prev_line = line
        line = lines.shift
        body << line.strip
      end until (line == "\n" and prev_line == "\n") or lines.length <= 0
      commit[:body] = body[0..-3]

      while lines[0] == "\n"
        lines.shift
      end

      files = []
      line = ''
      begin
        line = lines.shift
        if match = line.match(/(^\w)(\d*)\t([^\s]*)(?:\s+(.*))?/)
          # Similarity is for renames
          type, similarity, file1, file2 = match.captures
          files << { :type => type, :similarity => similarity, :file => file1, :newfile => file2 }
        end
      end until line == "\n" or lines.length <= 0
      commit[:files] = files

      commits << commit
    end

    commits
  end

  def git_installed?
    null = RbConfig::CONFIG['host_os'] =~ /msdos|mswin|djgpp|mingw/ ? 'NUL' : '/dev/null'
    system "git --version>>#{null} 2>&1"
  end
end
