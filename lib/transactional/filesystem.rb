module Transactional
  class FileSystem
    def initialize(transaction, root)
      @root = root
      @tfiles = []
      @tdirs = []
      @transaction = transaction
    end

    def open(rpath)
      @tfiles << TFile.load(@root, rpath)
      @tfiles.last.open {|f| yield f if block_given?}
      rescue Exception => ex
        @transaction.rollback
    end

    def create_directory(rpath)
     tdir = TDir.new(@root, rpath)
     tdir.create
     @tdirs << tdir
    end

    def commit
      @tfiles.each {|tfile| tfile.commit}
    end

    def rollback
      @tdirs.each  {|tdir|  tdir.rollback}
      @tfiles.each {|tfile| tfile.rollback}
    end
  end
end