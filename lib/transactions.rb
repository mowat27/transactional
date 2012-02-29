module Transactional
  class FileSystem
    def initialize(root)
      @root = root
    end

    def create_file(rpath)
      target = File.join(@root, rpath)
      File.open(target, "w") {}
    end
  end

  def self.start_transaction
    yield
  end

  def self.create_filesystem(filesystem_root)
    FileSystem.new(filesystem_root)
  end
end