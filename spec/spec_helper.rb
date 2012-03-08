SPEC_HOME = File.expand_path(File.dirname(__FILE__))
lib_dir = File.join(SPEC_HOME, "..", "lib")
$: << lib_dir

require 'fileutils'
require 'transactional'

def filesystem_root
  File.join(SPEC_HOME, "test_filesystem")
end

def testdir_rpath
  'testdir'
end

def testfile_rpath
  'testfile'
end

def testfile_path
  File.join(filesystem_root, testfile_rpath)
end

def testdir_path
  File.join(filesystem_root, testdir_rpath)
end

def testfile
  Transactional::Test::TestFile.new(testfile_path)
end

def testdir
  Transactional::Test::TestDir.new(testdir_path)
end

def lockfile
  Transactional::Test::TestFile.new("#{testfile_path}.lock")
end

def create_empty_filesytem
  if File.directory? filesystem_root
    FileUtils.rm_rf filesystem_root
  end
  FileUtils.mkdir filesystem_root
end

def start_transaction
  Transactional::Transaction.run do |transaction|
    filesystem = transaction.create_file_system(filesystem_root)
    yield filesystem, transaction
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

  module TestFileSystemObject
    def initialize(path)
      @path = path
    end
  end

  class TestDir
    include TestFileSystemObject

    def present?
      File.directory?(@path)
    end
  end

  class TestFile
    include TestFileSystemObject

    attr_reader :path

    def empty?
      File.read(@path) == ""
    end

    def present?
      File.file?(@path)
    end

    def data
      File.read(@path)
    end

    def data=(content)
      File.open(@path, "w") {|f| f.print content}
    end
  end
end
