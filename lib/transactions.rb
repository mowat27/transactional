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
    def rollback
      @filesystem.rollback if @filesystem
    end

    def create_filesystem(filesystem_root)
      @filesystem = FileSystem.new(filesystem_root)
    end
  end

  def self.start_transaction
    yield Transaction.new
  end
end