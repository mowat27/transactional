require 'spec_helper'

describe Transactional do
  let(:filesystem_root) { File.join(SPEC_HOME, "test_filesystem") }
  let(:testfile_rpath)  { "testfile" }
  let(:testfile_path)   { File.join(filesystem_root, testfile_rpath) }
  let(:testfile)        { TestFile.new(testfile_path) }
  let(:lockfile)        { TestFile.new("#{testfile_path}.lock") }

  def start_transaction
    Transactional::start_transaction do |transaction|
      filesystem = transaction.create_file_system(filesystem_root)
      yield filesystem, transaction
    end
  end

  class TestFile
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

  before do
    if File.directory? filesystem_root
      FileUtils.rm_rf filesystem_root
    end
    FileUtils.mkdir filesystem_root
  end

  describe "Integration Tests" do
    describe "writing a file inside a transaction" do
      context "when the transaction is sucessful" do
        it "creates a new file" do
          start_transaction do |filesystem, transaction|
            filesystem.open testfile_rpath
            testfile.should be_present
          end
          testfile.should be_present
          testfile.should be_empty
        end

        it "overwrites an existing file" do
          testfile.data = "hello world"
          start_transaction do |filesystem, transaction|
            filesystem.open(testfile_rpath) do |f|
              f.print "goodbye world"
            end
          end
          testfile.data.should == "goodbye world"
        end
      end

      context "when the transaction is rolled back" do
        context "and the file was created inside the transaction" do
          it "it deletes the file" do
            start_transaction do |filesystem, transaction|
              filesystem.open testfile_rpath

              testfile.should be_present
              testfile.should be_empty
              transaction.rollback
              testfile.should_not be_present
            end
            testfile.should_not be_present
          end

          it "deletes the lock file" do
            start_transaction do |filesystem, transaction|
              filesystem.open testfile_rpath do |f|
                lockfile.should be_present
                transaction.rollback
              end
            end
            lockfile.should_not be_present
          end
        end

        it "rolls and existing file back to its original data" do
          testfile.data = "hello world"
          start_transaction do |filesystem, transaction|
            filesystem.open(testfile_rpath) do |f|
              f.print "goodbye world"
            end
            transaction.rollback
          end
          testfile.data.should == "hello world"
        end
      end

      context "when an error causes the transaction to fail" do
        before do
          File.stub(:open).and_raise(Exception.new("something went wrong"))
        end

        it "rolls back the transaction" do
          start_transaction do |filesystem, transaction|
            transaction.should_receive(:rollback)

            filesystem.open(testfile_rpath) do |f|
              f.print "goodbye world"
            end
          end
        end
      end
    end
  end

  describe Transactional::Transaction do
    let(:filesystem1) { mock("filesystem") }
    let(:filesystem2) { mock("filesystem 2") }
    let(:transaction) { Transactional::Transaction.new }

    before do
      Transactional::FileSystem.stub(:new).and_return(filesystem1, filesystem2)
    end

    context "with a single filesystem" do
      it "rolls back the filesystem" do
        fs = transaction.create_file_system(filesystem_root)
        fs.should_receive(:rollback)
        transaction.rollback
      end
    end

    context "with many filesystems" do
      it "rolls back all filesystems" do
        fs1 = transaction.create_file_system(filesystem_root)
        fs2 = transaction.create_file_system(filesystem_root)
        fs1.should_receive(:rollback)
        fs2.should_receive(:rollback)
        transaction.rollback
      end
    end
  end

  describe Transactional::FileSystem do
    let(:transaction) {mock("a transaction")}
    before do
      @filesystem = Transactional::FileSystem.new(transaction, filesystem_root)
    end

    it "writes a file" do
      @filesystem.open testfile_rpath
      testfile.should be_present
    end

    it "rolls back a file" do
      @filesystem.open testfile_rpath
      @filesystem.rollback
      testfile.should_not be_present
    end

    context "when an error occurs on a file operation" do
      it "rolls back its parent transaction" do
        File.any_instance.stub(:open).and_raise(Exception.new("something went wrong"))
        transaction.should_receive(:rollback)
        @filesystem.open(testfile_rpath) do |f|
          f.open
        end
      end
    end
  end

  describe Transactional::TFile do
    let(:tfile) {Transactional::TFile.load(filesystem_root, testfile_rpath)}

    it "writes data to a file" do
      tfile.open {|f| f.print "data"}
      testfile.data.should == "data"
    end

    describe ".open" do
      it "delegates to File.open" do
        opts = {mode: "", external_encoding: "utf-8"}
        File.stub(:open)
        FileUtils.stub(:rm)
        File.should_receive(:open).with(testfile_path, opts)
        tfile.open(opts)
      end

      it "returns a file handle when no block is given" do
        tfile.open.class.should == File
      end
    end

    context "when the file does not previously exist" do
      it "deletes updates when rolled back" do
        tfile.open {|f| f.puts "data"}
        tfile.rollback
        testfile.should_not be_present
      end

      it "deletes lockfile when rolled back" do
        tfile.open do |f|
          f.puts "data"
        end
        tfile.rollback
        lockfile.should_not be_present
      end

      it "deletes the lockfile when rolled back inside the file write" do
        tfile.open do |f|
          f.puts "data"
          tfile.rollback
        end
        lockfile.should_not be_present
      end

      it "does nothing on rollback when no updates have been made" do
        tfile.rollback
        testfile.should_not be_present
      end

      describe '.open' do
        it "raises an error when the file is already open" do
          tfile.open do |f1|
            expect {
              tfile2 = Transactional::TFile.load(filesystem_root, testfile_rpath)
              tfile2.open
            }.to raise_error(Transactional::AccessError, /#{testfile_path} is already open/)
          end
        end
      end
    end

    context "when the file previously exists" do
      before do
        testfile.data = "original data"
      end

      it "appends data to the file" do
        tfile.open("a") {|f| f.print " + more data"}
        testfile.data.should == "original data + more data"
      end

      it "reads the file" do
        tfile.open("r") {|f| f.gets.should == "original data"}
      end

      it "reverts to the original content of the file when rolled back" do
        tfile.open {|f| f.puts "new data"}
        tfile.rollback
        testfile.data.should == "original data"
      end

      describe '.open' do
        it "raises an error when the file is already open" do
          tfile.open do |f1|
            expect {
              tfile2 = Transactional::TFile.load(filesystem_root, testfile_rpath)
              tfile2.open
            }.to raise_error(Transactional::AccessError, /#{testfile_path} is already open/)
          end
        end
      end
    end
  end
end
