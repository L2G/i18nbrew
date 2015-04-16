require 'formula'
require 'keg'
require 'bottles'

module Homebrew
  def cleanup
    # individual cleanup_ methods should also check for the existence of the
    # appropriate directories before assuming they exist
    return unless HOMEBREW_CELLAR.directory?

    if ARGV.named.empty?
      cleanup_cellar
      cleanup_cache
      cleanup_logs
      unless ARGV.dry_run?
        cleanup_lockfiles
        rm_DS_Store
      end
    else
      ARGV.formulae.each { |f| cleanup_formula(f) }
    end
  end

  def cleanup_logs
    return unless HOMEBREW_LOGS.directory?
    time = Time.now - 2 * 7 * 24 * 60 * 60 # two weeks
    HOMEBREW_LOGS.subdirs.each do |dir|
      cleanup_path(dir) { dir.rmtree } if dir.mtime < time
    end
  end

  def cleanup_cellar
    HOMEBREW_CELLAR.subdirs.each do |rack|
      begin
        cleanup_formula Formulary.factory(rack.basename.to_s)
      rescue FormulaUnavailableError
        # Don't complain about directories from DIY installs
      end
    end
  end

  def cleanup_formula f
    if f.installed?
      eligible_kegs = f.rack.subdirs.map { |d| Keg.new(d) }.select { |k| f.pkg_version > k.version }
      eligible_kegs.each do |keg|
        if f.can_cleanup?
          cleanup_keg(keg)
        else
          opoo t('cmd.cleanup.skipping_keg_only', :name => keg)
        end
      end
    elsif f.rack.subdirs.length > 1
      # If the cellar only has one version installed, don't complain
      # that we can't tell which one to keep.
      opoo t('cmd.cleanup.only_one_version',
             :name => f.name,
             :version => f.pkg_version)
    end
  end

  def cleanup_keg keg
    if keg.linked?
      opoo t('cmd.cleanup.skipping_linked_keg', :name => keg)
    else
      cleanup_path(keg) { keg.uninstall }
    end
  end

  def cleanup_cache
    return unless HOMEBREW_CACHE.directory?
    HOMEBREW_CACHE.children.select(&:file?).each do |file|
      next unless (version = file.version)
      next unless (name = file.basename.to_s[/(.*)-(?:#{Regexp.escape(version)})/, 1])

      begin
        f = Formulary.factory(name)
      rescue FormulaUnavailableError
        next
      end

      if f.version > version || ARGV.switch?('s') && !f.installed? || bottle_file_outdated?(f, file)
        cleanup_path(file) { file.unlink }
      end
    end
  end

  def cleanup_path(path)
    if ARGV.dry_run?
      puts t('cmd.cleanup.removing_path_dry_run',
             :path => path,
             :abv => path.abv)
    else
      puts t('cmd.cleanup.removing_path',
             :path => path,
             :abv => path.abv)
      yield
    end
  end

  def cleanup_lockfiles
    return unless HOMEBREW_CACHE_FORMULA.directory?
    candidates = HOMEBREW_CACHE_FORMULA.children
    lockfiles  = candidates.select { |f| f.file? && f.extname == '.brewing' }
    lockfiles.select(&:readable?).each do |file|
      file.open.flock(File::LOCK_EX | File::LOCK_NB) and file.unlink
    end
  end

  def rm_DS_Store
    paths = %w[Cellar Frameworks Library bin etc include lib opt sbin share var].
      map { |p| HOMEBREW_PREFIX/p }.select(&:exist?)
    args = paths.map(&:to_s) + %w[-name .DS_Store -delete]
    quiet_system "find", *args
  end

end

class Formula
  def can_cleanup?
    # It used to be the case that keg-only kegs could not be cleaned up, because
    # older brews were built against the full path to the keg-only keg. Then we
    # introduced the opt symlink, and built against that instead. So provided
    # no brew exists that was built against an old-style keg-only keg, we can
    # remove it.
    if not keg_only? or ARGV.force?
      true
    elsif opt_prefix.directory?
      # SHA records were added to INSTALL_RECEIPTS the same day as opt symlinks
      !Formula.installed.
        select{ |ff| ff.deps.map{ |d| d.to_s }.include? name }.
        map{ |ff| ff.rack.subdirs rescue [] }.
        flatten.
        map{ |keg_path| Tab.for_keg(keg_path).HEAD }.
        include? nil
    end
  end
end
