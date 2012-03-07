SPEC_HOME = File.expand_path(File.dirname(__FILE__))
lib_dir = File.join(SPEC_HOME, "..", "lib")
$: << lib_dir

require 'fileutils'
require 'transactional'

def start_transaction
  Transactional::start_transaction do |transaction|
    filesystem = transaction.create_file_system(filesystem_root)
    yield filesystem, transaction
    transaction.commit
  end
end

module Transactional::Test
  module TFileHelpers
    def it_creates_data_file(it_does = true)
      if it_does
        it "creates a data file" do
          testfile.should be_present
        end
      else
        it "does not create a data file" do
          testfile.should_not be_present
        end
      end
    end

    def it_deletes_lockfile
      it "deletes the lock file" do
        lockfile.should_not be_present
      end
    end
  end

  class TestFile
    attr_reader :path

    def initialize(path)
      @path = path
    end

    def empty?
      File.read(@path) == ""
    end

    def present?
      File.exists?(@path)
    end

    def data
      File.read(@path)
    end

    def data=(content)
      File.open(@path, "w") {|f| f.print content}
    end
  end
end
