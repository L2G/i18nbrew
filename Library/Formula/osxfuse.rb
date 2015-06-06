class Osxfuse < Formula
  desc "FUSE for OS X: extend native file handling via 3rd-party file systems"
  homepage "https://osxfuse.github.io/"
  url "https://github.com/osxfuse/osxfuse.git", :tag => "osxfuse-2.7.6",
                                                :revision => "6ba1962e153e7a76f43bc2f80b0ba0ef2da2cef9"

  head "https://github.com/osxfuse/osxfuse.git", :branch => "osxfuse-2"

  bottle do
    sha256 "ea6deeb6e94eaf5eeaf4dd6c9e66cf631ca3c97628991f060c7e5bf9eefc4228" => :mavericks
    sha256 "5254872690d09b78408530f85b52dd5c93ddc9db11cb6042019e89aca0dabd10" => :mountain_lion
  end

  depends_on :macos => :snow_leopard
  depends_on :xcode => :build

  # A fairly heinous hack to workaround our dependency resolution getting upset
  # See https://github.com/Homebrew/homebrew/issues/35073
  depends_on ConflictsWithBinaryOsxfuse => :build
  depends_on UnsignedKextRequirement => [ :cask => "osxfuse",
      :download => "http://sourceforge.net/projects/osxfuse/files/" ]

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "gettext" => :build

  def install
    # Do not override Xcode build settings
    ENV.remove_cc_etc

    system "./build.sh", "-t", "homebrew", "-f", prefix
  end

  def caveats; <<-EOS.undent
    If upgrading from a previous version of osxfuse, the previous kernel extension
    will need to be unloaded before installing the new version. First, check that
    no FUSE-based file systems are running:

      mount -t osxfusefs

    Unmount all FUSE file systems and then unload the kernel extension:

      sudo kextunload -b com.github.osxfuse.filesystems.osxfusefs

    The new osxfuse file system bundle needs to be installed by the root user:

      sudo /bin/cp -RfX #{opt_prefix}/Library/Filesystems/osxfusefs.fs /Library/Filesystems/
      sudo chmod +s /Library/Filesystems/osxfusefs.fs/Support/load_osxfusefs
    EOS
  end
end
