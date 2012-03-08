module Transactional
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
end