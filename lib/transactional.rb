module Transactional
  def self.start_transaction
    transaction = Transaction.new
    yield transaction
    transaction.commit
  end

  class Transaction
    def initialize
      @filesystems = []
    end

    def rollback
      @filesystems.each {|filesystem| filesystem.rollback}
    end

    def commit
      @filesystems.each {|filesystem| filesystem.commit}
    end

    def create_file_system(filesystem_root)
      @filesystems << FileSystem.new(self, filesystem_root)
      @filesystems.last
    end
  end

  class FileSystem
    def initialize(transaction, root)
      @root = root
      @tfiles = []
      @transaction = transaction
    end

    def open(rpath)
      @tfiles << TFile.load(@root, rpath)
      @tfiles.last.open {|f| yield f if block_given?}
      rescue Exception => ex
        @transaction.rollback
    end

    def commit
      @tfiles.each {|tfile| tfile.commit}
    end

    def rollback
      @tfiles.each {|tfile| tfile.rollback}
    end
  end

  class TFile
    def self.load(root, rpath)
      target = File.join(root, rpath)
      if File.exists? target
        ExistingTFile.new(target)
      else
        NewTFile.new(target)
      end
    end

    def open(opts = {mode: "w"}, &block)
      raise AccessError.new("#{@path} is already open") if @lockfile.exists?
      @lockfile.create
      File.open(@path, opts, &block)
    end

    def commit
      @lockfile.delete
    end

    private
    def initialize(path)
      @path = path
      @lockfile = LockFile.new(@path)
    end
  end

  class LockFile
    def initialize(parent_path)
      @parent_path = parent_path
      @lock_path = "#{@parent_path}.lock"
    end

    def create
      if File.exists? @parent_path
        FileUtils.cp @parent_path, @lock_path
      else
        File.open(@lock_path, "w") {}
      end
    end

    def delete
      FileUtils.rm(@lock_path) if File.exists? @lock_path
    end

    def exists?
      File.exists?(@lock_path)
    end

    def restore
      FileUtils.mv @lock_path, @parent_path
    end
  end

  class NewTFile < TFile
    def rollback
      FileUtils.rm @path if File.exists? @path
      @lockfile.delete
    end
  end

  class ExistingTFile < TFile
    def rollback
      @lockfile.restore
    end
  end

  class AccessError < Exception; end
end