module Transactional
  class TDir
    def initialize(root = nil, rpath = nil)
      @path = File.join(root, rpath)
    end

    def create
      FileUtils.mkdir @path
    end

    def rollback
      FileUtils.rmdir @path
    end
  end
end