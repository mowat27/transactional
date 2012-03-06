module Transactional
  def self.start_transaction
    transaction = Transaction.new
    yield transaction
  end

  class Transaction
    def initialize
      @filesystems = []
    end

    def rollback
      @filesystems.each {|filesystem| filesystem.rollback}
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
      result = File.open(@path, opts, &block)
      @lockfile.delete
      result
    end

    private
    def initialize(path)
      @path = path
      @lockfile = LockFile.new(@path)
    end
  end

  class LockFile
    def initialize(parent_path)
      @path = "#{parent_path}.lock"
    end

    def create
      File.open(@path, "w") {}
    end

    def delete
      FileUtils.rm(@path) if File.exists? @path
    end

    def exists?
      File.exists?(@path)
    end
  end

  class NewTFile < TFile
    def rollback
      FileUtils.rm @path if File.exists? @path
      @lockfile.delete
    end
  end

  class ExistingTFile < TFile
    def initialize(path)
      super
      @original_data = File.read(@path)
    end

    def rollback
      File.open(@path, "w") {|f| f.print @original_data}
    end
  end

  class AccessError < Exception; end
end