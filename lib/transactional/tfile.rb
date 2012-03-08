module Transactional
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
      File.open(@path, opts) do |f|
        yield f if block_given?
      end
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

  class AccessError < Exception; end
end