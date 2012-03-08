module Transactional
  class Transaction
    def self.run
      transaction = self.new
      yield transaction if block_given?
      transaction.commit
    end

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
end