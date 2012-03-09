module Transactional
  class FileSystem < TDir
    def initialize(transaction, root)
      super(root, "")
      @transaction = transaction
    end

    def open(rpath)
      super
      rescue Exception => ex
        @transaction.rollback
    end
  end
end