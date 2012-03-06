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
      transaction.commit
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

  after do
    lockfile.should_not be_present
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

        context "and the file existed before the transaction" do
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

          it "deletes the lock file" do
            testfile.data = "hello world"
            start_transaction do |filesystem, transaction|
              filesystem.open(testfile_rpath) do |f|
                f.print "goodbye world"
                lockfile.should be_present
                transaction.rollback
              end
            end
            lockfile.should_not be_present
          end
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
      let(:filesystem) { transaction.create_file_system(filesystem_root) }

      [:commit, :rollback].each do |operation|
        it "#{operation}s the filesystem on #{operation}" do
          filesystem.should_receive(operation)
          transaction.send operation
        end
      end
    end

    context "with many filesystems" do
      let(:fs1) { transaction.create_file_system(filesystem_root) }
      let(:fs2) { transaction.create_file_system(filesystem_root) }

      [:commit, :rollback].each do |operation|
        it "#{operation}s all filesystems on #{operation}" do
          fs1.should_receive(operation)
          fs2.should_receive(operation)
          transaction.send operation
        end
      end
    end
  end

  describe Transactional::FileSystem do
    let(:transaction) { mock("a transaction") }
    let(:filesystem)  { Transactional::FileSystem.new(transaction, filesystem_root) }

    it "writes a file on commit" do
      filesystem.open testfile_rpath
      filesystem.commit
      testfile.should be_present
    end

    it "rolls back a file" do
      filesystem.open testfile_rpath
      filesystem.rollback
      testfile.should_not be_present
    end

    context "when an error occurs on a file operation" do
      it "rolls back its parent transaction" do
        File.any_instance.stub(:open).and_raise(Exception.new("something went wrong"))
        transaction.should_receive(:rollback)
        filesystem.open(testfile_rpath) do |f|
          f.open
        end
        filesystem.commit
      end
    end
  end

  describe Transactional::TFile do
    let(:tfile) { Transactional::TFile.load(filesystem_root, testfile_rpath) }

    describe ".open" do
      after do
        tfile.commit
      end

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

      it "raises an error when the file is already open" do
        tfile.open do |f1|
          expect {
            tfile2 = Transactional::TFile.load(filesystem_root, testfile_rpath)
            tfile2.open
          }.to raise_error(Transactional::AccessError, /#{testfile_path} is already open/)
        end
      end
    end

    context "when the file does not previously exist" do
      context "on commit" do
        context "after file write" do
          before do
            tfile.open {|f| f.puts "data"}
            tfile.commit
          end
          it "creates a data file" do
            testfile.should be_present
          end
          it "deletes the lock file" do
            lockfile.should_not be_present
          end
        end

        context "during file write" do
          before do
            tfile.open do |f|
              f.puts "data"
              tfile.commit
            end
          end
          it "creates a data file" do
            testfile.should be_present
          end
          it "deletes the lock file" do
            lockfile.should_not be_present
          end
        end
      end

      context "on rollback" do
        context "when no changes were made" do
          before {tfile.rollback}
          it "does not create a data file" do
            testfile.should_not be_present
          end
          it "does not create a lockfile" do
            lockfile.should_not be_present
          end
        end

        context "after file write" do
          before do
            tfile.open {|f| f.puts "data"}
            tfile.rollback
          end
          it "deletes the file" do
            testfile.should_not be_present
          end
          it "deletes the lockfile" do
            lockfile.should_not be_present
          end
        end
      end

      context "during file write" do
        before do
          tfile.open do |f|
            f.puts "data"
            tfile.rollback
          end
        end
        it "deletes the file" do
          testfile.should_not be_present
        end
        it "deletes the lockfile" do
          lockfile.should_not be_present
        end
      end
    end

    context "when the file previously exists" do
      before do
        testfile.data = "original data"
      end

      it "appends data to the file" do
        tfile.open("a") {|f| f.print " + more data"}
        tfile.commit
        testfile.data.should == "original data + more data"
      end

      it "reads the file" do
        tfile.open("r") {|f| f.gets.should == "original data"}
        tfile.commit
      end

      context "on commit" do
        before do
          tfile.open {|f| f.print "new data"}
          tfile.commit
        end
        it "preserves to the changes made" do
          testfile.data.should == "new data"
        end
        it "deletes the lock file" do
          lockfile.should_not be_present
        end
      end

      context "on rollback" do
        before do
          tfile.open {|f| f.print "new data"}
          tfile.rollback
        end
        it "reverts to the original content" do
          testfile.data.should == "original data"
        end
        it "deletes the lock file" do
          lockfile.should_not be_present
        end
      end
    end
  end
end
