require 'spec_helper'

describe Transactional::TDir do
  let(:tdir) { Transactional::TDir.new(filesystem_root, testdir_rpath) }
  let(:testdir2_rpath) { "testdir2" }
  let(:testdir2)  { Transactional::Test::TestDir.new(File.join(filesystem_root, testdir_rpath, testdir2_rpath)) }
  let(:testfile2_rpath) { "testfile2" }
  let(:testfile2) { Transactional::Test::TestFile.new(File.join(testdir.path, testfile2_rpath)) }
  let(:testdir3_rpath) { "testfile3" }
  let(:testfile3) { Transactional::Test::TestFile.new(File.join(testdir.path, testdir3_rpath)) }

  before { reset_test_filesytem }

  describe "#create" do
    it "returns the tdir object for the directory created" do
      tdir.create.should == tdir
    end
  end

  describe "#open" do
    it "returns the tfile object for the file created" do
      tdir.create
      tfile = Transactional::TFile.load(testdir.path, "newfile")
      Transactional::TFile.stub(:new => tfile)
      tdir.open("newfile").should == tfile
    end
  end

  describe "#create_directory" do
    it "returns the tdir object for the directory created" do
      tdir.create
      new_tdir = Transactional::TDir.new(testdir.path, "newdir")
      Transactional::TDir.stub(:new => new_tdir)
      tdir.create_directory("newdir").should == new_tdir
    end
  end

  context "when the directory exists" do
    before { FileUtils.mkdir testdir_path }

    describe "#create" do
      it "does nothing" do
        tdir.create
        testdir.should be_present
      end
    end
  end

  context "when a directory is created" do
    before { tdir.create }
    it "creates a directory" do
      testdir.should be_present
      tdir.commit
    end

    it "deletes the directory when rolled back" do
      tdir.rollback
      testdir.should_not be_present
    end
  end

  context "when no directory is created" do
    it "does nothing when rolled back" do
      tdir.rollback
      testdir.should_not be_present
    end
  end

  context "on commit" do
    before { tdir.create }

    it "writes files" do
      new_file = tdir.open testfile2_rpath
      new_file.should_receive(:commit)
      tdir.commit
      testfile2.should be_present
    end

    it "writes directories" do
      new_dir = tdir.create_directory testdir2_rpath
      new_dir.should_receive(:commit)
      tdir.commit
      testdir2.should be_present
    end
  end

  context "on rollback" do
    before { tdir.create }

    it "rolls back files" do
      tdir.open testfile2_rpath
      tdir.rollback
      testfile2.should_not be_present
    end

    it "rolls back directories" do
      tdir.create_directory testdir2_rpath
      tdir.rollback
      testdir2.should_not be_present
    end

    it "rolls back nested directories and files" do
      tdir.open("subfile1")
      tdir.create_directory("subdir").open("subfile2")
      tdir.open("subfile3")
      tdir.rollback

      testdir.should_not be_present
    end
  end
end
