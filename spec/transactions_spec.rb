require 'spec_helper'


describe Transactional do
  let(:filesystem_root) { File.join(SPEC_HOME, "test_filesystem") }
  let(:testfile_rpath)  { "testfile" }
  let(:testfile_path)   { File.join(filesystem_root, testfile_rpath) }

  before do
    if File.directory? filesystem_root
      FileUtils.rm_rf filesystem_root
    end
    FileUtils.mkdir filesystem_root
  end

  def start_transaction
    Transactional::start_transaction do |transaction|
      filesystem = transaction.create_file_system(filesystem_root)
      yield filesystem, transaction
    end
  end

  describe "writing a file inside a transaction" do
    context "when the transaction is sucessful" do
      it "creates a new file" do
        start_transaction do |filesystem, transaction|
          filesystem.write_file testfile_rpath
          File.exists?(testfile_path).should be_true
        end
        File.exists?(testfile_path).should be_true
        File.read(testfile_path).should == ""
      end

      it "overwrites an existing file" do
        File.open(testfile_path, "w") {|f| f.print "hello world"}
        start_transaction do |filesystem, transaction|
          filesystem.write_file(testfile_rpath) do |f|
            f.print "goodbye world"
          end
        end
        File.read(testfile_path).should == "goodbye world"
      end
    end

    context "when the transaction fails" do
      it "it deletes a newly created file" do
        start_transaction do |filesystem, transaction|
          filesystem.write_file testfile_rpath

          File.exists?(testfile_path).should be_true
          File.read(testfile_path).should == ""
          transaction.rollback
          File.exists?(testfile_path).should be_false
        end
        File.exists?(testfile_path).should be_false
      end

      it "rolls and existing file back to its original data" do
        File.open(testfile_path, "w") {|f| f.print "hello world"}
        start_transaction do |filesystem, transaction|
          filesystem.write_file(testfile_rpath) do |f|
            f.print "goodbye world"
          end
          transaction.rollback
        end
        File.read(testfile_path).should == "hello world"
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
    before do
      @filesystem = Transactional::FileSystem.new(filesystem_root)
    end

    it "writes a file" do
      @filesystem.write_file testfile_rpath
      File.exists?(testfile_path).should be_true
    end

    it "rolls back a file" do
      @filesystem.write_file testfile_rpath
      @filesystem.rollback
      File.exists?(testfile_path).should be_false
    end
  end

  describe Transactional::TFile do
    let(:file) {Transactional::TFile.load(filesystem_root, testfile_rpath)}

    it "writes data to a file" do
      file.open {|f| f.print "data"}
      File.read(testfile_path).should == "data"
    end

    context "when the file does not previously exist" do
      it "deletes updates when rolled back" do
        file.open {|f| f.puts "data"}
        file.rollback
        File.exists?(testfile_path).should be_false
      end

      it "does nothing on rollback when no updates have been made" do
        file.rollback
        File.exists?(testfile_path).should be_false
      end
    end

    context "when the file previously exists" do
      before do
        File.open(testfile_path, "w") {|f| f.print "original data"}
      end

      it "reverts to the original content of the file when rolled back" do
        file.open {|f| f.puts "new data"}
        file.rollback
        File.read(testfile_path).should == "original data"
      end
    end
  end
end

