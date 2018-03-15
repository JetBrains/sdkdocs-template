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
  # Make sure we run before the TOC generator
  priority :high

  def generate(site)
    raise "Git is not installed" unless git_installed?

    recents_output = site.config['recently_updated_output'] || 'recently_updated.md'
    data = site.frontmatter_defaults.all(recents_output, :pages).clone
    data['title'] = 'Recently Updated'
    data['edit_on_github'] = false

    pages_by_path = Hash.new
    site.pages.each { |p| pages_by_path[p.path] = p }

    toc = site.data['toc']
    toc_by_path = Hash.new
    toc_by_id = Hash.new
    toc.each { |e| handle_toc_entry(toc_by_path, toc_by_id, e) }

    github_repo = site.config['github_repo']
    youtrack_project = site.config['youtrack_project']
    toc = site.data['toc']
    content = header(github_repo)
    content << format_commits(commits, github_repo, youtrack_project, pages_by_path, toc_by_path, toc_by_id)
    #content << commits.to_s

    recents_page = RecentsPage.new(site, site.source, '/', recents_output, content, data)
    site.pages << recents_page
  end

  def handle_toc_entry(toc_by_path, toc_by_id, entry)
    toc_by_id[entry[:id]] = entry
    toc_by_path[entry[:path]] = entry if entry.key?(:path)
    if entry.key?(:pages) then
      entry[:pages].each { |p| handle_toc_entry(toc_by_path, toc_by_id, p) }
    end
  end

  def header(github_repo)
    "See the [full changelog on GitHub](https://github.com/#{github_repo}/commits/)\n"
  end

  def format_commits(commits, github_repo, youtrack_project, pages_by_path, toc_by_path, toc_by_id)
    content = ''

    prev_date = ''
    commits.each do |c|

      if c[:files].any? {|f| not should_skip(f[:file]) } then

        date = c[:date].strftime('%-d %B %Y')
        content << "<hr>\n## #{date}\n" unless date == prev_date
        content << "\n"
        content << "**#{format_message(c[:subject], github_repo, youtrack_project)}** ([view diff](https://github.com/#{github_repo}/commit/#{c[:hash]}))\n"
        body = c[:body].join()
        content << "<br>#{format_message(body, github_repo, youtrack_project)}\n"

        content << "\n"
        c[:files].each do |f|
          file = f[:file]
          if not should_skip(file) then
            case f[:type]
            when 'D'
              content << "* `#{file}` (deleted)\n"
            when 'R'
                newfile = f[:newfile]
                content << format_file(newfile, pages_by_path, toc_by_path, toc_by_id)
                content << " (renamed from `#{file}`)\n"
            else
              data = format_file(file, pages_by_path, toc_by_path, toc_by_id)
              content << data + "\n" if data
            end
          end
        end
        content << "\n"

        prev_date = date
      end
    end

    content
  end

  def should_skip(file)
    file == '_SUMMARY.md' or file == 'README.md' or file == 'CONTRIBUTING.md' or not file.end_with?('.md')
  end

  def format_file(file, pages_by_path, toc_by_path, toc_by_id)
    return nil unless pages_by_path.key?(file)
    raise "Page is not in ToC: #{file}" unless toc_by_path.key?(file)

    page = pages_by_path[file]
    title = page.data['title']
    toc_entry = toc_by_path[file]
    title = toc_entry[:title]
    path = format_path(toc_entry, toc_by_id)

    "* #{path} **[#{title}](/#{file})**"
  end

  def format_path(toc_entry, toc_by_id)
    path = ""
    parent_id = toc_entry[:parent_id]
    if not parent_id.nil? then
      parent_toc = toc_by_id[parent_id]

      path << format_path(parent_toc, toc_by_id) if parent_toc.key?(:parent_id)

      title = parent_toc[:title]
      if parent_toc.key?(:path) then
        path << "[#{title}](/#{parent_toc[:path]})"
      else
        path << title
      end
      path << " / "
    end
    path
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
