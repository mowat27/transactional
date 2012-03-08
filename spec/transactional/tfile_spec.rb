require 'spec_helper'

describe Transactional::TFile do
  extend Transactional::Test::TFileHelpers

  let(:tfile) { Transactional::TFile.load(filesystem_root, testfile_rpath) }

  before { create_empty_filesytem }
  after  { lockfile.should_not be_present }

  describe ".open" do
    after do
      tfile.commit
    end

    it "delegates to File.open" do
      opts = {mode: "w", external_encoding: "utf-8"}
      Transactional::LockFile.any_instance.stub(:create)
      File.should_receive(:open).with(testfile_path, opts)
      tfile.open(opts)
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
        it_creates_data_file
        it_deletes_lockfile
      end

      context "during file write" do
        before do
          tfile.open do |f|
            f.puts "data"
            tfile.commit
          end
        end
        it_creates_data_file
        it_deletes_lockfile
      end
    end

    context "on rollback" do
      context "when no changes were made" do
        before {tfile.rollback}
        it_creates_data_file(false)
        it_deletes_lockfile
      end

      context "after file write" do
        before do
          tfile.open {|f| f.puts "data"}
          tfile.rollback
        end
        it_creates_data_file(false)
        it_deletes_lockfile
      end

      context "during file write" do
        before do
          tfile.open do |f|
            f.puts "data"
            tfile.rollback
          end
        end
        it_creates_data_file(false)
        it_deletes_lockfile
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
      it_deletes_lockfile
    end

    context "on rollback" do
      before do
        tfile.open {|f| f.print "new data"}
        tfile.rollback
      end
      it "reverts to the original content" do
        testfile.data.should == "original data"
      end
      it_deletes_lockfile
    end
  end
end
