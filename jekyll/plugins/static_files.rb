class CopiedStaticFile < Jekyll::StaticFile

  def initialize(site, base, source_dir, dest_dir, name)
    super(site, base, source_dir, name)
    @dest_dir = dest_dir
  end

  def destination_rel_dir
    @dest_dir
  end
end

class StaticFilesGenerator < Jekyll::Generator

  def generate(site)
    site.config['static_files'].each do |k,v|
      Dir.glob(k).reject { |x| File.directory?(x) }.each do |src|
        site.static_files << CopiedStaticFile.new(site, site.source, File.dirname(src), v, File.basename(src))
      end
    end
  end
end
