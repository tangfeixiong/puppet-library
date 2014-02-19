require 'spec_helper'

module PuppetLibrary::Forge
    describe GitRepository do
        let(:repo_path) { Tempdir.create("git-repo") }
        let(:versions) { [ "0.9.0", "1.0.0-rc1", "1.0.0" ] }
        let(:tags) { versions + [ "xxx" ] }
        let(:forge) { GitRepository.new("puppetlabs", "apache", /[0-9.]+/, repo_path) }

        before do
            def git(command)
                `git --git-dir=#{repo_path}/.git --work-tree=#{repo_path} #{command}`
                unless $?.success?
                    raise "Failed to run command: \"#{git_command}\""
                end
            end

            git "init"
            versions.zip(tags).each do |(version, tag)|
                File.open(File.join(repo_path, "Modulefile"), "w") do |modulefile|
                    modulefile.write <<-MODULEFILE
                    name 'puppetlabs-apache'
                    version '#{version}'
                    author 'puppetlabs'
                    MODULEFILE
                end
                git "add ."
                git "commit --message='Version #{version}'"
                git "tag #{tag}"
            end
        end

        after do
            rm_rf repo_path
        end

        describe "#get_module" do
            context "when the requested author is different from the configured author" do
                it "returns nil" do
                    buffer = forge.get_module("dodgybrothers", "apache", "1.0.0")
                    expect(buffer).to be_nil
                end
            end

            context "when the requested module name is different from the configured name" do
                it "returns nil" do
                    buffer = forge.get_module("puppetlabs", "stdlib", "1.0.0")
                    expect(buffer).to be_nil
                end
            end

            context "when the tag for the requested version doesn't exist" do
                it "returns nil" do
                    buffer = forge.get_module("puppetlabs", "apache", "9.9.9")
                    expect(buffer).to be_nil
                end
            end

            context "when the module is requested" do
                it "returns an archive of the module" do
                    buffer = forge.get_module("puppetlabs", "apache", "1.0.0")
                    expect(buffer).to be_tgz_with "puppetlabs-apache-1.0.0/Modulefile", /version '1.0.0'/
                end
                it "generates the metadata file and includes it in the archive" do
                    buffer = forge.get_module("puppetlabs", "apache", "1.0.0")
                    expect(buffer).to be_tgz_with "puppetlabs-apache-1.0.0/metadata.json", /"version"=>"1.0.0"/
                end
            end
        end

        describe "#get_metadata" do
            context "when the requested author is different from the configured author" do
                it "returns nil" do
                    metadata = forge.get_metadata("dodgybrothers", "apache")
                    expect(metadata).to be_empty
                end
            end

            context "when the requested module name is different from the configured name" do
                it "returns an empty array" do
                    metadata = forge.get_metadata("puppetlabs", "stdlib")
                    expect(metadata).to be_empty
                end
            end

            context "when the module is requested" do
                it "generates the metadata for the each version" do
                    metadata = forge.get_metadata("puppetlabs", "apache")
                    expect(metadata).to have(3).versions
                    expect(metadata.first["name"]).to eq "puppetlabs-apache"
                    expect(metadata.first["version"]).to eq "0.9.0"
                end
            end
        end
    end
end