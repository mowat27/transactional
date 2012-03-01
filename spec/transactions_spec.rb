require 'spec_helper'


describe Transactional do
  let(:filesystem_root) { File.join(SPEC_HOME, "test_filesystem") }
  let(:testfile_name)   { "testfile" }
  let(:testfile_path)   { File.join(filesystem_root, testfile_name) }

  def start_transaction
    Transactional::start_transaction do |transaction|
      filesystem = transaction.create_file_system(filesystem_root)
      yield filesystem, transaction
    end
  end

  describe "writing a file inside a transaction" do
    before do
      if File.directory? filesystem_root
        FileUtils.rm_rf filesystem_root
      end
      FileUtils.mkdir filesystem_root
    end

    context "when the transaction is sucessful" do
      it "creates a new file" do
        start_transaction do |filesystem, transaction|
          filesystem.write_file testfile_name
          File.exists?(testfile_path).should be_true
        end
        File.exists?(testfile_path).should be_true
        File.read(testfile_path).should == ""
      end

      it "overwrites an existing file" do
        File.open(testfile_path, "w") {|f| f.print "hello world"}
        start_transaction do |filesystem, transaction|
          filesystem.write_file(testfile_name) do |f|
            f.print "goodbye world"
          end
        end
        File.read(testfile_path).should == "goodbye world"
      end
    end

    context "when the transaction fails" do
      it "it deletes a newly created file" do
        start_transaction do |filesystem, transaction|
          filesystem.write_file testfile_name

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
          filesystem.write_file(testfile_name) do |f|
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
      File.should_receive(:open).with(testfile_path, "w")
      @filesystem.write_file testfile_name
    end
  end
end