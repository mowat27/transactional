module Transactional
  class TDir
    def initialize(root, rpath)
      @path = File.join(root, rpath)
      @children = []
    end

    def create
      FileUtils.mkdir @path unless File.exists? @path
      self
    end

    def rollback
      @children.each {|child| child.rollback}
      FileUtils.rmdir @path
    end

    def commit
      @children.each {|child| child.commit}
    end

    def open(rpath)
      @children << TFile.load(@path, rpath)
      @children.last.open {|f| yield f if block_given?}
      @children.last
    end

    def create_directory(rpath)
      @children << TDir.new(@path, rpath)
      @children.last.create
    end
  end
end