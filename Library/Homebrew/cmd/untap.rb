require 'cmd/tap' # for tap_args

module Homebrew
  def untap
    raise t("cmd.untap.error_usage") if ARGV.empty?

    ARGV.each do |tapname|
      user, repo = tap_args(tapname)

      # we consistently downcase in tap to ensure we are not bitten by case-insensive
      # filesystem issues. Which is the default on mac. The problem being the
      # filesystem cares, but our regexps don't. So unless we resolve *every* path
      # we will get bitten.
      user.downcase!
      repo.downcase!

      tapd = HOMEBREW_LIBRARY/"Taps/#{user}/homebrew-#{repo}"

      raise t("cmd.untap.error_no_such_tap") unless tapd.directory?
      puts t("cmd.untap.untapping", :name => tapname, :abv => tapd.abv)

      files = []
      tapd.find_formula { |file| files << file }
      unlink_tap_formula(files)
      tapd.rmtree
      tapd.dirname.rmdir_if_possible
      puts t("cmd.untap.untapped_formulae", :count => files.length)
    end
  end

  def unlink_tap_formula paths
    untapped = 0
    gitignores = (HOMEBREW_LIBRARY/"Formula/.gitignore").read.split rescue []

    paths.each do |path|
      link = HOMEBREW_LIBRARY.join("Formula", path.basename)

      if link.symlink? && (!link.exist? || link.resolved_path == path)
        link.delete
        gitignores.delete(path.basename.to_s)
        untapped += 1
      end
    end

    HOMEBREW_REPOSITORY.join("Library/Formula/.gitignore").atomic_write(gitignores * "\n")

    untapped
  end
end
