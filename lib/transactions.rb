module Transactional
  class FileSystem
    def initialize(root)
      @root = root
    end

    def create_file(rpath)
      target = File.join(@root, rpath)
      File.open(target, "w") {}
      @file_created = target
    end

    def rollback
      FileUtils.rm @file_created
    end
  end

  class Transaction
    def initialize
      @filesystems = []
    end

    def rollback
      @filesystems.each {|filesystem| filesystem.rollback}
    end

    def create_filesystem(filesystem_root)
      result = FileSystem.new(filesystem_root)
      @filesystems << result
      result
    end
  end

  def self.start_transaction
    yield Transaction.new
  end
end