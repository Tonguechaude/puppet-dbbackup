# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'dbbackup' do
  let(:date) { Time.now.strftime('%Y-%m-%d') }

  context 'with basic params' do
    let(:backup_dir) { "/var/test/dumps/#{date}" }
    let(:pp) do
      'include dbbackup'
    end

    it 'applies without errors' do
      apply_manifest(pp, catch_failures: true)
    end

    it 'applies idempotently' do
      apply_manifest(pp, catch_changes: true)
    end

    describe service('dump_databases.timer') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe file('/usr/local/bin/dump_databases') do
      it { is_expected.to be_executable }
    end

    it 'forces the backup service to run' do
      result = shell('systemctl start dump_databases.service')
      expect(result.exit_code).to eq(0)
    end

    describe command('/usr/local/bin/dump_databases') do
      its(:exit_status) { is_expected.to eq 0 }
    end

    it 'runs the dump script and creates the backup dumps' do
      tries = 0
      until File.directory?(backup_dir) || tries >= 10
        sleep(6)
        tries += 1
      end

      raise "Backup directory #{backup_dir} does not exist after waiting" unless File.directory?(backup_dir)

      dumps1 = Dir.glob("#{backup_dir}/*.mysql.gz")
      dumps2 = Dir.glob("#{backup_dir}/*.psql.gz")
      expect(dumps1).not_to be_empty
      expect(dumps2).not_to be_empty
    end
  end

  context 'with custom params' do
    let(:backup_custom_dir) { "/var/dumps/#{date}" }
    let(:pp) do
      "class { 'dbbackup':
        destination => '/var/dumps'
      }"
    end

    it 'applies without errors' do
      apply_manifest(pp, catch_failures: true)
    end

    it 'applies idempotently' do
      apply_manifest(pp, catch_changes: true)
    end

    describe service('dump_databases.timer') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe file('/usr/local/bin/dump_databases') do
      it { is_expected.to be_executable }
    end

    it 'forces the backup service to run' do
      result = shell('systemctl start dump_databases.service')
      expect(result.exit_code).to eq(0)
    end

    describe command('/usr/local/bin/dump_databases') do
      its(:exit_status) { is_expected.to eq 0 }
    end

    it 'runs the dump script and creates the backup dumps' do
      backup_dir_exists = false
      10.times do
        result = shell("test -d #{backup_custom_dir}", acceptable_exit_codes: [0, 1])
        if result.exit_code == 0
          backup_dir_exists = true
          break
        end
        sleep(6)
      end
      raise "Backup directory #{backup_custom_dir} does not exist after waiting" unless File.directory?(backup_custom_dir)

      describe command("ls #{backup_custom_dir}/*.mysql.gz") do
        its(:exit_status) { is_expected.to eq 0 }
      end

      describe command("ls #{backup_custom_dir}/*.psql.gz") do
        its(:exit_status) { is_expected.to eq 0 }
      end
    end
  end
end
